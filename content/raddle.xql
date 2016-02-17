xquery version "3.1";

module namespace raddle="http://lagua.nl/lib/raddle";
import module namespace console="http://exist-db.org/xquery/console";

(:
- http://www.w3.org/TR/xquery-30/#prod-xquery30-NCName
- http://www.w3.org/TR/REC-xml-names
- http://stackoverflow.com/questions/1631396/what-is-an-xsncname-type-and-when-should-it-be-used
- http://stackoverflow.com/questions/14891129/regular-expression-pl-and-pn
:)

declare variable $raddle:suffix := "\+\*\-\?";
declare variable $raddle:ncname := "\p{L}\p{N}\-_\."; (: actually variables shouldn't start with number :)
declare variable $raddle:qname := "[" || $raddle:ncname || "]*:?" || "[" || $raddle:ncname || "]+";

(:
Following https://www.w3.org/TR/xquery-31/#id-precedence-order
to ensure that raddle operators conform to xquery.
Unary ops need to be checked in syntax parsing
Arrow op is useless
TODO we may support bitwise operators, increment/decrement operators, assignment operators, etc.
:)

declare variable $raddle:operators := [
	",",
	("some", "every", "switch", "typeswitch", "try", "if"),
	"or",
	"and",
	("eq", "ne", "lt", "le", "gt", "ge", "=", "!=", "<=", ">=", "<<", ">>", "<", ">", "is"),
	"||",
	"to",
	("+","-"),
	("div", "idiv", "mod"),
	("union","|"),
	("intersect", "except"),
	"instance of",
	"treat as",
	"castable as",
	"cast as",
	"=>",
	("+","-"),
	"!",
	("/","//"),
	("filter","?")
];

declare variable $raddle:chars := $raddle:suffix || $raddle:ncname || "\$:%/#@\^";

declare variable $raddle:filter-regexp := "(\])|(,)?([^\[\]]*)(\[?)";
declare variable $raddle:operator-regexp := "=#[0-9]+=";
declare variable $raddle:paren-regexp := concat("(\)[",$raddle:suffix,"]?)|(",$raddle:operator-regexp,"|,)?([",$raddle:chars,"]*)(\(?)");
declare variable $raddle:protocol-regexp := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$";
declare variable $raddle:json-query-compatible := true();

declare variable $raddle:type-map := map {
	"any" := "xs:anyAtomicType",
	"element" := "element()",
	"item" := "item()",
	"array" := "array(item()?)",
	"map" := "map(xs:string,item()?)",
	"string" := "xs:string",
	"int" := "xs:int",
	"integer" := "xs:integer",
	"boolean" := "xs:boolean",
	"decimal" := "xs:decimal",
	"float" := "xs:float"
};

declare variable $raddle:auto-converted := map {
	"true" := "true()",
	"false" := "false()",
	"null" := "()",
	"undefined" := "()",
	"Infinity" := "1 div 0e0",
	"-Infinity" := "-1 div 0e0"
};

declare function raddle:escape-for-regex($arg as xs:string?) as xs:string {
	replace($arg,'(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
} ;

declare function raddle:map-put($map,$key,$val){
	map:new(($map,map {$key := $val}))
};

declare function raddle:parse-strings($strings as element()*) {
	raddle:wrap(analyze-string(string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	})),$raddle:paren-regexp)/fn:match,$strings)
};

declare function raddle:parse($query as xs:string?){
	raddle:parse($query,map {})
};

declare function raddle:parse($query as xs:string?,$params) {
	raddle:parse-strings(analyze-string(raddle:normalize-query($query,$params),"'[^']*'")/*)
};

declare function raddle:get-index-from-tokens($tok) {
	for-each(1 to count(index-of($tok,1)),function($i){
		if(exists(index-of($tok,-1)[$i]) and index-of($tok,-1)[$i] < index-of($tok,1)[$i]) then
			()
		else
			index-of($tok,1)[$i]+1
	})
};

declare function raddle:get-index($rest){
	raddle:get-index-from-tokens(for-each($rest,function($_){
		if($_/fn:group[@nr=1]) then
			1
		else if($_/fn:group[@nr=4]) then
			-1
		else
			0
	}))[1]
};

declare function raddle:clip-string($str as xs:string) {
	substring($str,2,string-length($str)-2)
};

declare function raddle:value-from-strings($val as xs:string,$strings) {
	(: TODO replace :)
	if(matches($val,"\$%[0-9]+")) then
		raddle:clip-string($strings[number(replace($val,"\$%([0-9]+)","$1"))])
	else
		$val
};

declare function raddle:append-or-nest($next,$strings,$group,$ret,$suffix){
	let $x :=
		if($group[@nr=3]) then
			map { "name" := raddle:value-from-strings($group[@nr=3]/string(),$strings), "args" := raddle:wrap($next,$strings), "suffix" := $suffix}
		else
			raddle:wrap($next,$strings)
	return
		if(matches($group[@nr=2]/string(),"^" || $raddle:operator-regexp || "$")) then
			let $rev := array:reverse($ret)
			let $last := array:head($rev)
			let $operator := $group[@nr=2]/string()
			let $null := console:log($operator)
			return array:append(array:reverse(array:tail($rev)),map { "name" := $operator, "args" := [$last, $x], "suffix" := ""})
		else
			array:append($ret,$x)
};

declare function raddle:append-prop-or-value($string,$operator,$strings,$ret) {
	if(matches($operator, $raddle:operator-regexp || "+")) then
		if(array:size($ret)>0) then
			let $rev := array:reverse($ret)
			let $last := array:head($rev)
			let $has-preceding-op := $last instance of map(xs:string?,item()?) and matches($last("name"),$raddle:operator-regexp)
			(: for unary operators :)
			let $operator :=
				if($has-preceding-op and array:size($last("args")) = 1) then
					raddle:unary-op($operator)
				else
					$operator
			let $map :=
				if($has-preceding-op and raddle:op-num($operator) > raddle:op-num($last("name"))) then
					(: if operator > preceding swap the nesting :)
					map { "name" := $last("name"), "args" := [$last("args")(1),map { "name" := $operator, "args" :=
						if(array:size($last("args"))>1) then
							[$last("args")(2),raddle:value-from-strings($string,$strings)]
						else
							[raddle:value-from-strings($string,$strings)], "suffix" := ""}], "suffix" := ""}
				else
					if(exists($string)) then
						map { "name" := $operator, "args" := [$last, raddle:value-from-strings($string,$strings)], "suffix" := ""}
					else
						map { "name" := $operator, "args" := [$last], "suffix" := ""}
			return array:append(array:reverse(array:tail($rev)),$map)
		else
			let $null := console:log($operator)
			return array:append($ret,map { "name" := $operator, "args" := raddle:value-from-strings($string,$strings), "suffix" := ""})
	else
		array:append($ret,raddle:value-from-strings($string,$strings))
};

declare function raddle:unary-op($op){
	concat("=#", raddle:op-num($op) + 14,"=")
};

declare function raddle:op-num($op){
	number(replace($op,"[=#]",""))
};

declare function raddle:wrap-open-paren($rest,$strings,$index,$group,$ret){
	raddle:wrap(subsequence($rest,$index),$strings,
		raddle:append-or-nest(subsequence($rest,1,$index),$strings,$group,$ret,replace($rest[$index - 1],"\)","")))
};

declare function raddle:wrap($rest,$strings,$ret,$group){
	if(exists($rest)) then
		if($group[@nr=4]) then
			raddle:wrap-open-paren($rest,$strings,raddle:get-index($rest),$group,$ret)
		else if($group[@nr=3] or matches($group[@nr=2]/string(),$raddle:operator-regexp || "+|,")) then
			let $null := if(matches($group[@nr=2]/string(),$raddle:operator-regexp || "+")) then
				console:log($group)
			else
				()
			return raddle:wrap($rest,$strings,raddle:append-prop-or-value($group[@nr=3]/string(),$group[@nr=2]/string(),$strings,$ret))
		else
			raddle:wrap($rest,$strings,$ret)
	else
		$ret
};

declare function raddle:wrap($match,$strings,$ret){
	raddle:wrap(tail($match),$strings,$ret,head($match)/fn:group)
};

declare function raddle:wrap($match,$strings){
	raddle:wrap($match,$strings,[])
};

declare function raddle:wrap-open-square($rest,$params,$index,$group,$ret){
	raddle:wrap-square(subsequence($rest,$index),$params,
		if($group[@nr=3]) then
			(: empty string indicates there was a group before :)
			if($group[@nr=3]/string()="") then
				let $rev := array:reverse($ret)
				let $prev := array:head($rev)
				return array:append(array:reverse(array:tail($rev)),[$prev(1),$prev(2) || "=filter=" || raddle:normalize-filter(raddle:wrap-square(subsequence($rest,1,$index),$params),$params)])
			else if(matches($group[@nr=3]/string(),"(\.|\)|\$\p{N}+)$")) then
				let $val :=
						string-join(array:flatten(raddle:wrap-square(subsequence($rest,1,$index),$params)))
				return array:append($ret,[
					replace($group[@nr=3]/string(),"(\.|\)|\$\p{N}+)$",""),
					replace($group[@nr=3]/string(), "^(.*)(\.|\)|\$\p{N}+)$","$2=filter=") || raddle:normalize-filter($val,$params)
				])
			else
				array:append($ret,[$group[@nr=3]/string(),"array(" || raddle:wrap-square(subsequence($rest,1,$index),$params) || ")"])
		else
			array:append($ret,raddle:wrap-square(subsequence($rest,1,$index),$params))
	)
};

declare function raddle:wrap-square($rest,$params,$ret,$group){
	if(exists($rest)) then
		if($group[@nr=4]) then
			raddle:wrap-open-square($rest,$params,raddle:get-index($rest),$group,$ret)
		else if($group[@nr=3] or $group[@nr=2]/string() = ",") then
			raddle:wrap-square($rest,$params,array:append($ret,
				$group[@nr=3]/string()
			))
		else
			raddle:wrap-square($rest,$params,$ret)
	else
		$ret
};

declare function raddle:wrap-square($match,$params,$ret){
	raddle:wrap-square(tail($match),$params,$ret,head($match)/fn:group)
};

declare function raddle:wrap-square($match,$params){
	raddle:wrap-square($match,$params,[])
};

declare function raddle:normalize-filter($query as xs:string?, $params as map(xs:string*,item()?)) {
	let $query :=
		if(matches($query,"^[\+\-]?\p{N}+$")) then (: TODO replace correct integers :)
			"position(.)=#16=" || $query
		else
			$query
	return "(" || $query || ")"
};

declare function raddle:normalize-query($query as xs:string?,$params) {
	let $query := replace(replace($query,"&#9;|&#10;|&#13;","")," ","%20")
	let $query := string-join(array:flatten(raddle:wrap-square(analyze-string($query,$raddle:filter-regexp)/fn:match,$params)))
	let $query := replace($query,"%3A",":")
	let $query := replace($query,"%2C",",")
	let $query :=
		if($raddle:json-query-compatible) then
			let $query := replace($query,"%3C=","=le=")
			let $query := replace($query,"%3E=","=ge=")
			let $query := replace($query,"%3C","=lt=")
			let $query := replace($query,"%3E","=gt=")
			return $query
		else
			$query
	(: normalize to xquery :)
	(: TODO backwards support RQL, >= and <= will always be incompatible... :)
	let $query := replace($query,"%20+","%20")
	(: prevent operator overwrites :)
	let $query := replace($query,"===","=#16=")
	let $ops := array:flatten($raddle:operators)
	let $query := fold-left(1 to count($ops),$query,function($cur,$next){
		if($next ne 1 and $next ne 16) then
			let $op := replace(raddle:escape-for-regex($ops[$next])," ","[ =]+")
			let $cur := replace($cur,"=" || $op || "=","=#" || $next || "=")
			return
				if(matches($ops[$next],"\w+")) then
					replace($cur,"%20" || $op || "%20","=#" || $next || "=")
				else
					replace($cur,"([^=]?)" || $op || "([^=]?)","$1=#" || $next || "=$2")
		else
			$cur
	})
	(: prevent = ambiguity with xquery's hopelessly outdated regex engine... :)
	let $query := replace($query,"=(#[0-9]+)=","%20$1%20")
	(: prevent = overwrite :)
	let $query := replace($query,"([^=]?)=([^=]?)","$1=#16=$2")
	let $query := replace($query,"%20(#[0-9]+)%20","=$1=")
	let $query := replace($query,"%20=|=%20","=")
	(: TODO check if there are any ops left and either throw or fix :)
	return $query
};

declare function raddle:convert($string){
	if(matches($string,"^(\$.*)|([^#]+#[0-9]+)$")) then
		$string
	else if(map:contains($raddle:auto-converted,$string)) then
		$raddle:auto-converted($string)
	else
		if(string(number($string)) = 'NaN') then
			"&quot;" || util:unescape-uri($string,"UTF-8") || "&quot;"
		else
			number($string)
};

declare function raddle:import-module($name,$params){
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

declare function raddle:get-uri-info($path) {
	let $parts := tokenize($path,"/")
	let $resource := $parts[last()]
	return map {
		"collection" := string-join(subsequence($parts,1,count($parts)-1),"/"),
		"resource" := $resource,
		"ext" := replace($resource,"^.*(\.\w+)|([^.]*)$","$1")
	}
};

declare function raddle:normalize-uri($protocol,$path,$params) {
	let $info := raddle:get-uri-info($path)
	let $info := raddle:map-put($info,"ext",if($info("ext") eq "") then
			".rdl"
		else
			$info("ext"))
	let $info := raddle:map-put($info,"location",
		concat(
			if(empty($protocol)) then
				$params("raddled") || "/"
			else if($protocol = "xmldb:exist") then
				"/"
			else
				""
		,$info("collection"),(if($info("collection") eq "") then "" else "/"),$info("resource"),$info("ext")))
	(: TODO add parent for partial modules :)
	return raddle:map-put($info,"parent",replace($info("collection"), ".*/(.*)", "$1"))
};

declare function raddle:create-uri($path as xs:string, $params as item()*) {
	let $groups := analyze-string($path,$raddle:protocol-regexp)//fn:group
	return raddle:normalize-uri($groups[@nr = 2]/text(),$groups[@nr = 3]/text(),$params)
};

declare function raddle:module($value,$params){
	let $desc := $value("args")
	return
		map {
			"prefix" := $desc(1),
			"uri" := $desc(2),
			"description" := $desc(3)
		}
};

declare function raddle:use($value,$params){
	map:new(
		array:flatten(
			array:for-each($value("args"),function($_){
				let $uri := raddle:create-uri($_,$params)
				let $src := util:binary-to-string(util:binary-doc($uri("location")))
				let $parsed := raddle:parse($src,$params)
				return raddle:process($parsed,raddle:map-put($params,"use",$uri))
			})
		)
	)
};

declare function raddle:process($value,$body,$params){
	let $mod :=
		array:filter($value,function($arg){
			$arg("name")="module"
		})
	let $module :=
		if(array:size($mod)>0) then
			raddle:module($mod(1),$params)
		else
			()
	let $params :=
		if(exists($module)) then
			map:new(($params,map { "module" := $module}))
		else
			$params
	let $use :=
		array:filter($value,function($arg){
			$arg("name")="use"
		})
	let $dict :=
		map:new(($params("dict"),
			for $i in 1 to array:size($use) return
				raddle:use($use($i),$params)
		))
	(: update params dict! :)
	let $params := map:new(($params,map:entry("dict",$dict)))
	let $declare :=
		array:filter($value,function($arg){
			$arg("name")=("declare","define")
		})
	let $declare :=
		array:for-each($declare,function($arg){
			if($arg("name")="define") then
				raddle:map-put($arg,"args",array:insert-before($arg("args"),1,if(matches($arg("args")(1),"^\$.*")) then "variable" else "function"))
			else
				$arg
		})
	let $dict :=
		map:new(($dict,
			for $i in 1 to array:size($declare)
				let $def := raddle:declare($declare($i),$params)
				return map:entry($def("qname"),$def)
		))
	(: update params dict! :)
	let $params := map:new(($params,map:entry("dict",$dict)))
	return
		(: TODO add module info to dictionary :)
		if(array:size($mod)>0) then
			raddle:insert-module($dict,$params)
		else if(array:size($body)>0) then
			raddle:map-put($dict, "anon:top#1",
				map {
					"name":="top",
					"qname":="anon:top#1",
					"body":=$body(1),
					"func":=raddle:compile($body(1),(),(),raddle:map-put($params,"top",true()))
				})
		else $dict
};


declare function raddle:process($value,$params){
	raddle:process(
		array:filter($value,function($arg){
			$arg instance of map(xs:string*,item()?) and $arg("name") = ("use","define","module","declare")
		}),
		array:filter($value,function($arg){
			not($arg instance of map(xs:string*,item()?) and $arg("name") = ("use","define","module","declare"))
		}),$params)
};

declare function raddle:create-module($dict,$params){
	raddle:create-module($dict,$params,false())
};

declare function raddle:create-module($dict,$params,$top){
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	let $module :=
		if(map:contains($params,"module")) then
			$params("module")
		else
			()
	let $default :=
		if(map:contains($params,"default-namespace-prefix")) then
			$params("default-namespace-prefix")
		else
			"fn"
	let $mods :=
		for $key in map:keys($dict) return
			if(matches($key,"^local:|^anon:")) then
				()
			else
				$dict($key)("prefix")
	let $import :=
		for $prefix in distinct-values($mods) return
			if($prefix) then
				let $entry := $map[@prefix = $prefix]
				return
					if($entry/@location) then
						"import module namespace " || $prefix || "=&quot;" || $entry/@uri || "&quot; at &quot;" || $entry/@location || "&quot;;"
					else
						if($prefix ne $default and $prefix ne "local" and (not(exists($module)) or $module("prefix") ne $prefix)) then
							"declare namespace " || $prefix || "=&quot;" || $entry/@uri || "&quot;;"
						else
							()
			else
				()
	let $vars :=
		for $key in map:keys($dict) return
			if(map:contains($dict($key),"value")) then
				$dict($key)
			else
				()
	let $variable :=
		for $var in $vars return
			"declare variable " || $var("qname") || " as " || raddle:map-type($var("type")) || (if($var("value")) then " := " || $var("value") else "") || ";"
	let $local :=
		for $key in map:keys($dict) return
			if((exists($module) and starts-with($key,$module("prefix") || ":")) or matches($key,"^local:")) then
				let $ret := $dict($key)("func")
				let $pre := substring($ret,1,8)
				let $ret :=
					if($pre eq "function") then
						substring($ret,9)
					else
						"(){" || $ret || "}"
				return
					"declare function " || $dict($key)("qname") || $ret || ";"
			else
				()
	let $anon :=
		for $key in map:keys($dict) return
			if(matches($key,"^anon:")) then
				$dict($key)("func")
			else
				()
	let $moduledef :=
		if(exists($module)) then
			(if($top) then "declare" else "module") || " namespace " || $module("prefix") || "=&quot;" || $module("uri") || "&quot;;&#xa;"
		else
			()
	let $defaultdef :=
		if($default ne "fn") then
			"declare default function namespace &quot;" || $map[@prefix=$default]/@uri || "&quot;;&#xa;"
		else
			""
	return "xquery version &quot;3.1&quot;;&#xa;" || $defaultdef || $moduledef || string-join(($variable,$import,$local,$anon),"&#xa;")
};

declare function raddle:insert-module($dict,$params){
	(: TODO: if 'use' in params, look for a precompiled module :)
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	let $module :=
		if(map:contains($params,"module")) then
			$params("module")
		else
			()
	let $default :=
		if(map:contains($params,"default-namespace-prefix")) then
			$params("default-namespace-prefix")
		else
			"fn"
	let $module :=
		if($map[@uri=$module("uri")]) then
			$module
		else
			let $modstr := raddle:create-module($dict,$params)
			return map:new(($module,map { "has_module" := true(),"func" := $modstr }))
	return map:new(($dict, map:new(map:entry($module("prefix"),$module))))
};

declare function raddle:is-fn-seq($value) {
	if(array:size($value) eq 0) then
		false()
	else
		let $type := distinct-values(array:flatten(
			array:for-each($value,function($_){
				if($_ instance of map(xs:string, item()?)) then
					(: only check strings in sequence :)
					raddle:is-fn-seq($_("args"))
				else if($_ instance of xs:string and $_ = ".") then
					true()
				else
					()
			})
		))
		return
			if(count($type)>1) then
				false()
			else
				$type
};

declare function raddle:serialize($value,$params){
	if($value instance of map(xs:string, item()?)) then
		$value("name") || (if(map:contains($value,"args")) then raddle:serialize($value("args"),$params) else "()") || (if(map:contains($value,"suffix")) then $value("suffix") else "")
	else if($value instance of array(item()?)) then
		"(" || string-join(array:flatten(array:for-each($value,function($val){
			if(exists($params)) then
				raddle:compile($val,(),(),$params)
			else
				raddle:serialize($val,$params)
		})),",") || ")"
	else
		if(exists($params)) then
			raddle:convert($value)
		else
			$value
};

declare function raddle:map-type($stype) {
	if(map:contains($raddle:type-map,$stype)) then
		replace($stype,$stype,map:get($raddle:type-map,$stype))
	else
		$stype
};

declare function raddle:compile($value,$parent,$compose,$params){
	let $top := $params("top")
	let $params := map:remove($params,"top")
	let $isSeq := $value instance of array(item()?)
	return
		if(not($isSeq or $value instance of map(xs:string, item()?))) then
			raddle:serialize($value,$params)
		else
	let $fn-seq := if($isSeq) then raddle:is-fn-seq($value) else false()
	let $ret :=
		if($isSeq) then
			if($fn-seq) then
				array:fold-left($value,"",function($pre,$cur){
					if($cur instance of map(xs:string, item()?)) then
						(: compose the functions in the array :)
						let $c := raddle:compile($cur,(),true(),$params)
						let $qname := array:head($c)
						(: TODO keep array and descend into it if nested :)
						let $args := array:flatten(array:tail($c))
						let $args :=
							if(count($args) > 0 and $pre ne "") then
								let $index := index-of($args,"$arg0")
								let $args := remove($args,$index)
								return insert-before($args,$index,$pre)
							else if($pre ne "") then
								insert-before($args,1,$pre)
							else
								$args
						return $qname || "(" || string-join($args,",") || ")"
					else
						""
				})
			else
				raddle:serialize($value,$params)
		else
			()
	let $fargs :=
		if(exists($parent)) then
			string-join((for $i in 1 to array:size($parent("args")) return
				let $type := $parent("args")($i)
				let $xsd :=
					if($type instance of map(xs:string, item()?)) then
						raddle:serialize($type,())
					else
						let $stype := replace($type,"[" || $raddle:suffix || "]?$","")
						return
							raddle:map-type($stype) || replace($type,"^[^" || $raddle:suffix || "]*","")
				return "$arg" || $i || " as " || $xsd
			),",")
		else
			"$arg0"
	(:
	let $fname :=
		if(exists($parent)) then
			let $parity := if($parent("more")) then "N" else array:size($parent("args"))
			$parent("qname")
		else
			"anon"
	:)
	return
		if($isSeq) then
			if($fn-seq) then
				"function(" || $fargs || "){" || $ret || "}"
			else
				if(exists($parent) or $top) then
					"function(" || $fargs || "){ " || $ret || "}"
				else
					$ret
		else
			let $arity := array:size($value("args"))
			let $qname := $value("name")
			let $args := $value("args")
			let $args :=
				array:for-each($args,function($_){
					if($_ instance of array(item()?)) then
						raddle:compile($_,(),(),$params)
					else if($_ instance of map(xs:string, item()?)) then
						raddle:compile($_,(),(),$params)
(:					else if(matches(string($_),"/")) then:)
						(: rewrite select path to arg sequence :)
(:						raddle:select(string($_),$params):)
					else if(string($_) = ".") then
						"$arg0"
					else if(matches(string($_),"^\$[0-9]+$")) then
						replace($_,"^\$([0-9]+)$","\$arg$1")
					else
						raddle:convert($_)
				})
			return
				if($qname eq "") then
					(: if qname empty, apply previous anonymous function with these args :)
					(: TODO if arg is int and qname atomic value, retrieve N from sequence :)
					"(" || string-join(array:flatten($args),",") || ")"
				else if(matches($qname,"^[$\.]")) then
					(: if qname is argument, variable or dot, apply with args or context function :)
					$qname || "(" || string-join(array:flatten($args),",") || ")"
				else if($compose) then
					array:insert-before($args,1,$qname)
				else
					(: TODO detect exec :)
					let $fn := $qname || "(" || string-join(array:flatten($args),",") || ")"
					return
						if(exists($parent) or $top) then
							"function(" || $fargs || "){ " || $fn || "}"
						else
							$fn
};

declare function raddle:declare($value,$params){
	let $type := array:head($value("args"))
	let $args := array:tail($value("args"))
	return switch ($type)
		case "namespace" return raddle:namespace($args,$params)
		case "variable" return raddle:variable($args,$params)
		default return raddle:define(map{"args":=$args},$params)
};

declare function raddle:namespace($args,$params) {
	map {
		"uri" := $args(2),
		"prefix" := $args(1)
	}
};

declare function raddle:variable($args,$params) {
	let $l := array:size($args)
	return map {
		"qname" := $args(1),
		"type" := $args(2),
		"value" :=
			if($l>2) then
				raddle:compile($args(3),(),(),$params)
			else
				()
	}
};

declare function raddle:define($value,$params){
	let $l := array:size($value("args"))
	let $name := $value("args")(1)
	let $default :=
		if(map:contains($params,"default-namespace-prefix")) then
			$params("default-namespace-prefix")
		else
			"fn"
	let $def :=
		if($l=2) then
			let $prefix :=
				if(map:contains($params,"use")) then
					$params("use")("parent")
				else if(map:contains($params,"module")) then
					$params("module")("prefix")
				else
					()
			let $qname :=
				if(contains($name,":")) then
					$name
				else
					if($prefix) then
						$prefix || ":" || $name
					else
						$name (: error? :)
			let $def := $params("dict")($value("args")(2))
			return map:new(($def,map:entry("qname",$qname)))
		else
			let $args := $value("args")(2)
			let $arity := array:size($args)
			let $type := $value("args")(3)
			let $parts := tokenize($name,":")
			(:
				assume the following:
				- namespace is in module definition
				- namespace is in parent definition
				- namespace is parent
			:)
			let $prefix :=
				if($l=3 and map:contains($params,"use")) then
					$params("use")("parent")
				else if(map:contains($params,"module")) then
					$params("module")("prefix")
				else
					"local"
			let $qname :=
				if(contains($name,":")) then
					$name
				else
					if($prefix) then
						$prefix || ":" || $name
					else
						$name
			let $def :=
				if(map:contains($params("dict"),$qname)) then
					map:get($params("dict"),$qname)
				else
					map {
						"qname" := $qname,
						"arity" := $arity,
						"prefix" := $prefix,
						"type" := $type,
						"args" := $args,
						"body" := if($l=3) then () else $value("args")(4)
					}
			return
				if($l=4 and not(map:contains($def,"func"))) then
					let $func := raddle:compile($def("body"),$def,(),$params)
					return map:new(($def,map { "func" := $func }))
				else
					$def
	return $def
};

declare function raddle:transpile($str,$params) {
	let $value := raddle:parse($str,$params)
	let $dict := raddle:process($value,$params)
	return
		if(map:contains($dict,"anon:top#1")) then
			(: TODO detect namespace declaration(s) :)
			raddle:create-module($dict,$params,true())
		else
			let $moduledefs :=
				map:for-each-entry($dict,function($key,$val){
					if(map:contains($val,"has_module") and $val("has_module") and map:contains($val,"func")) then
						$val("func")
					else
						()
				})
			return
				if(count($moduledefs) = 1) then
					$moduledefs[1]
				else if(map:contains($params,"module")) then
					raddle:create-module($dict,$params)
				else
					error(xs:QName("raddle:moduleError"), "Modules must be declared in the file or by passing a module definition parameter.")
};
