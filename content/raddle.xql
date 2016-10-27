xquery version "3.1";

module namespace rdl="http://raddle.org/raddle";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";
import module namespace n="http://raddle.org/native-xq" at "../lib/n.xql";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $rdl:suffix := "\+\*\-\?";
declare variable $rdl:ncname := $xqc:ncname;

declare variable $rdl:chars := $rdl:suffix || $rdl:ncname || "\$%/#@\^:";

declare variable $rdl:paren-regexp := concat("(\)[",$rdl:suffix,"]?)|(",$xqc:operator-regexp,"|,)?([",$rdl:chars,"]*)(\(?)");
declare variable $rdl:protocol-regexp := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$";


declare function rdl:map-put($map,$key,$val){
	map:new(($map,map {$key : $val}))
};

declare function rdl:parse-strings($strings as element()*,$normalizer,$params) {
    let $string := string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	}))
	let $string := $normalizer($string,$params)
	return array:join(for-each(tokenize($string,";"),function($block){
	    let $ret := rdl:wrap(analyze-string($block,$rdl:paren-regexp)/fn:match,$strings)
	    return xqc:rename($ret,function($name){
		if(matches($name,$xqc:operator-regexp)) then
			xqc:to-op(xqc:op-num($name))
		else
			$name
	    })
	}))
};

declare function rdl:normalize-query($query as xs:string?,$params){
	replace($query,"&#9;|&#10;|&#13;","")
};

declare function rdl:parse($query as xs:string?){
	rdl:parse($query,map {})
};

declare function rdl:parse($query as xs:string?,$params) {
	rdl:parse-strings(
		analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*,
		if($params("$compat") = "xquery") then
		    function($query,$params){
		        rdl:normalize-query(xqc:normalize-query($query,$params),$params)
		    }
		else
		    rdl:normalize-query#2,
		$params
	)
};

declare function rdl:get-index-from-tokens($tok) {
	for-each(1 to count(index-of($tok,1)),function($i){
	    let $x := index-of($tok,-1)[$i]
	    let $y := index-of($tok,1)[$i]
	    return
    		if(exists($x) and $x < $y) then
    			()
    		else
    			$y + 1
	})
};

declare function rdl:get-index($rest){
	rdl:get-index-from-tokens(for-each($rest,function($_){
	    let $_ := $_/fn:group/@nr
	    return
    		if($_ = 1) then
    			1
    		else if($_ = 4) then
    			-1
    		else
    			0
	}))[1]
};

declare function rdl:clip-string($str as xs:string) {
	substring($str,2,string-length($str)-2)
};

declare function rdl:value-from-strings($val as xs:string?,$strings) {
	(: TODO replace :)
	if(matches($val,"\$%[0-9]+")) then
		concat("&quot;",rdl:clip-string($strings[number(replace($val,"\$%([0-9]+)","$1"))]),"&quot;")
	else
		$val
};

declare function rdl:append-or-nest($next,$strings,$group,$ret,$suffix){
	let $x :=
		if($group[@nr=3]) then
			 map { "name" := rdl:value-from-strings($group[@nr=3]/string(),$strings), "args" := rdl:wrap($next,$strings), "suffix" := $suffix}
		else
			rdl:wrap($next,$strings)
	return
		if(matches($group[@nr=2]/string(),"^" || $xqc:operator-regexp || "$")) then
			let $operator := $group[@nr=2]/string()
			return if(array:size($ret)>0) then
				let $rev := array:reverse($ret)
				let $last := array:head($rev)
				let $ret := array:reverse(array:tail($rev))
				let $op := xqc:op-int($operator)
				(: check if preceded by comma :)
				return
					if(empty($last)) then
						array:append($ret,map { "name" := $operator, "args" := $x, "suffix" := ""})
					else
						let $has-preceding-op := $last instance of map(xs:string?,item()?) and matches($last("name"),$xqc:operator-regexp)
						let $prev-op := if($has-preceding-op) then xqc:op-int($last("name")) else ()
						let $preceeds := $has-preceding-op and $op > $prev-op and not($op eq 20 and $prev-op eq 19)
						return
							if($preceeds) then
(:								let $n := console:log(($op," > ",$prev-op ," || ",$x," || ",$last)) return:)
								let $y := map { "name" := $operator, "args" := [$last("args")(2),$x], "suffix" := ""}
								return array:append($ret,map { "name" := $last("name"), "args" := [$last("args")(1), $y], "suffix" := ""})
							else
								array:append($ret,map { "name" := $operator, "args" := [$last, $x], "suffix" := ""})

			else
				array:append($ret,map { "name" := $operator, "args" := $x, "suffix" := ""})
		else
			array:append($ret,$x)
};

declare function rdl:append-prop-or-value($string,$operator,$strings,$ret) {
	if(matches($operator, $xqc:operator-regexp || "+")) then
		if(array:size($ret)>0) then
			xqc:operator-precedence(if(exists($string)) then rdl:value-from-strings($string,$strings) else (),$operator,$ret)
		else
			array:append($ret,map { "name" := xqc:unary-op($operator), "args" := [rdl:value-from-strings($string,$strings)], "suffix" := ""})
	else
		array:append($ret,rdl:value-from-strings($string,$strings))
};

declare function rdl:wrap-open-paren($rest,$strings,$index,$group,$ret){
	rdl:wrap(subsequence($rest,$index),$strings,
		rdl:append-or-nest(subsequence($rest,1,$index),$strings,$group,$ret,replace($rest[$index - 1],"\)","")))
};

declare function rdl:wrap($rest,$strings,$ret,$group){
	if(exists($rest)) then
		if($group[@nr=4]) then
			rdl:wrap-open-paren($rest,$strings,rdl:get-index($rest),$group,$ret)
		else if($group[@nr=3] or matches($group[@nr=2]/string(),$xqc:operator-regexp || "+|,")) then
			rdl:wrap($rest,$strings,rdl:append-prop-or-value($group[@nr=3]/string(),$group[@nr=2]/string(),$strings,$ret))
		else
			rdl:wrap($rest,$strings,$ret)
	else
		$ret
};

declare function rdl:wrap($match,$strings,$ret){
	rdl:wrap(tail($match),$strings,$ret,head($match)/fn:group)
};

declare function rdl:wrap($match,$strings){
	rdl:wrap($match,$strings,[])
};

declare function rdl:import-module($name,$params){
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	let $location := xs:anyURI($map[@name = $name]/@location)
	let $uri := xs:anyURI($map[@name = $name]/@uri)
	let $module :=
		if($location) then
			inspect:inspect-module($location)
		else
			inspect:inspect-module-uri($uri)
	return n:try(util:import-module(xs:anyURI($module/@uri), $module/@prefix, xs:anyURI($module/@location)),())
};

declare function rdl:stringify($a,$params){
	rdl:stringify($a,$params,true())
};

declare function rdl:stringify($a,$params,$top){
	let $s := array:size($a)
	return
		a:fold-left-at($a,"",function($acc,$t,$i){
			let $type :=
				if($t instance of map(xs:string?,item()?)) then 1
				else if($t instance of array(item()?)) then 2
				else 0
			let $ret :=
				if($type eq 1) then
					concat($t("name"),"(",string-join(array:flatten(rdl:stringify($t("args"),$params,false())),","),")",if($t("suffix") instance of xs:string) then $t("suffix") else "")
				else if($type eq 2) then
					concat("(",rdl:stringify($t,$params,false()),")")
				else
					$t
			return concat($acc,if($i > 1 and not($type eq 1 and $t("name") eq "")) then if($top) then ",&#10;&#13;" else "," else "",$ret)
		})
};

declare function rdl:transpile($tree,$lang,$params){
    let $module := n:import("../lib/" || $lang || ".xql")
	let $frame := map:put($params,"$imports",map {
		"core": $module
	})
	let $func := $module("$exports")("core:transpile#2")
	return $func($tree,$frame)
};

declare function rdl:exec($query,$params){
	(: FIXME retrieve default-namespace :)
	let $core := n:import("../lib/core.xql")
	let $n := n:import("../lib/n.xql")
	return
		if(map:contains($params,"$transpile")) then
			if($params("$transpile") eq "rdl") then
				rdl:stringify(rdl:parse($query,$params),$params)
			else
				rdl:transpile(rdl:parse($query,$params),$params("$transpile"),$params)
		else
			let $frame := map:put($params,"$imports",map { "core": $core, "n": $n})
			let $fn := n:eval(rdl:parse($query,$params))
			return $fn($frame)
};

declare function rdl:clip($name){
	if(matches($name,"^&quot;.*&quot;$")) then rdl:clip-string($name) else $name
};

declare function rdl:camel-case($name){
	let $p := tokenize($name,"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};

declare function rdl:capitalize($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};
