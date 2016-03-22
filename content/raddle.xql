xquery version "3.1";

module namespace rdl="http://raddle.org/raddle";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";
import module namespace n="http://raddle.org/native-xq" at "../lib/n.xql";

import module namespace console="http://exist-db.org/xquery/console";
(:
- http://www.w3.org/TR/xquery-30/#prod-xquery30-NCName
- http://www.w3.org/TR/REC-xml-names
- http://stackoverflow.com/questions/1631396/what-is-an-xsncname-type-and-when-should-it-be-used
- http://stackoverflow.com/questions/14891129/regular-expression-pl-and-pn
:)

declare variable $rdl:suffix := "\+\*\-\?";
declare variable $rdl:ncname := $xqc:ncname;

(:
Following https://www.w3.org/TR/xquery-31/#id-precedence-order
to ensure that raddle operators conform to xquery.
Unary ops need to be checked in syntax parsing
Arrow op is useless
TODO we may support bitwise operators, increment/decrement operators, assignment operators, etc.
:)


declare variable $rdl:chars := $rdl:suffix || $xqc:ncname || "\$:%/#@\^";

declare variable $rdl:filter-regexp := "(\])|(,)?([^\[\]]*)(\[?)";

declare variable $rdl:paren-regexp := concat("(\)[",$rdl:suffix,"]?)|(",$xqc:operator-regexp,"|,)?([",$rdl:chars,"]*)(\(?)");
declare variable $rdl:protocol-regexp := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$";


declare function rdl:map-put($map,$key,$val){
	map:new(($map,map {$key := $val}))
};

declare function rdl:parse-strings($strings as element()*,$params) {
	rdl:wrap(analyze-string(xqc:normalize-query(string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	})),$params),$rdl:paren-regexp)/fn:match,$strings)
};

declare function rdl:parse($query as xs:string?){
	rdl:parse($query,map {})
};

declare function rdl:parse($query as xs:string?,$params) {
	rdl:parse-strings(analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*,$params)
};

declare function rdl:get-index-from-tokens($tok) {
	for-each(1 to count(index-of($tok,1)),function($i){
		if(exists(index-of($tok,-1)[$i]) and index-of($tok,-1)[$i] < index-of($tok,1)[$i]) then
			()
		else
			index-of($tok,1)[$i]+1
	})
};

declare function rdl:get-index($rest){
	rdl:get-index-from-tokens(for-each($rest,function($_){
		if($_/fn:group[@nr=1]) then
			1
		else if($_/fn:group[@nr=4]) then
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
				(: check if preceded by comma :)
				let $args :=
					if(empty($last)) then
						$x
					else
						[$last, $x]
				return array:append(array:reverse(array:tail($rev)),map { "name" := $operator, "args" := $args, "suffix" := ""})
			else
				array:append($ret,map { "name" := $operator, "args" := $x, "suffix" := ""})
		else
			array:append($ret,$x)
};

declare function rdl:append-prop-or-value($string,$operator,$strings,$ret) {
	if(matches($operator, $xqc:operator-regexp || "+")) then
		if(array:size($ret)>0) then
			xqc:operator-precedence(if(exists($string)) then rdl:value-from-strings($string,$strings) else	(),$operator,$ret)
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
	xqc:rename(rdl:wrap($match,$strings,[]),function($name){
		if(matches($name,$xqc:operator-regexp)) then
			xqc:to-op(xqc:op-num($name))
		else
			$name
	})
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
	return try {
		util:import-module(xs:anyURI($module/@uri), $module/@prefix, xs:anyURI($module/@location))
	} catch * {
		()
	}
};


declare function rdl:exec($query,$params){
	(: FIXME retrieve default-namespace :)
	let $core := n:import("../lib/core.xql")
	let $n := n:import("../lib/n.xql")
	return
		if(map:contains($params,"$transpile")) then
			let $module := n:import("../lib/transpile.xql")
			let $frame := map:put($params,"$imports",map {
				"core":$core,
				"":$module
			})
			return $module("$exports")("tp:transpile#3")(rdl:parse($query,$params),$frame,true())
		else
				let $frame := map:put($params,"$imports",map { "":$core,"n": $n})
				return n:eval(rdl:parse($query,$params))($frame)
};
