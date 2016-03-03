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

declare variable $raddle:xq-operators := map {
	1: ",",
	2.01: "some",
	2.02: "every",
	2.03: "switch",
	2.04: "typeswitch",
	2.05: "try",
	2.06: "if",
	2.07: "then",
	2.08: "else",
	2.09: "let",
	2.10: ":=",
	2.11: "return",
	3: "or",
	4: "and",
	5.01: "eq",
	5.02: "ne",
	5.03: "lt",
	5.04: "le",
	5.05: "gt",
	5.06: "ge",
	5.07: "=",
	5.08: "!=",
	5.10: "<=",
	5.11: ">=",
	5.12: "<<",
	5.13: ">>",
	5.14: "<",
	5.15: ">",
	5.16: "is",
	6: "||",
	7: "to",
	8.01: "+",
	8.02: "-",
	9.01: "*",
	9.02: "idiv",
	9.03: "div",
	9.04: "mod",
	10.01: "union",
	10.02: "|",
	11.01: "intersect",
	11.02: "except",
	12: "instance of",
	13: "treat as",
	14: "castable as",
	15: "cast as",
	16: "=>",
	17.01: "+",
	17.02: "-",
	18: "!",
	19.01: "/",
	19.02: "//",
	20.01: "[",
	20.02: "]",
	20.03: "?",
	20.04: "[",
	20.05: "{",
	20.06: "}",
	20.07: "@"
};

declare variable $raddle:xq-operators2 := [
	[","],
	["some", "let", ":=", "return", "every", "switch", "typeswitch"],
	["try", "if", "then", "else", "or"],
	["and"],
	["eq", "<=", ">=", "<<", ">>", "<", ">", "is", "ne", "lt", "le"],
	["gt", "ge", "=", "!=", "||"],
	["to"],
	["+", "-"],
	["*", "idiv", "div", "mod"],
	["union", "|"],
	["intersect", "except"],
	["instance of"],
	["treat as"],
	["castable as"],
	["cast as"],
	["=>"],
	["+", "-"],
	["!"],
	["/", "//"],
	["[", "]", "?"]
];

declare variable $raddle:operator-map := map {
	5.07: "geq",
	5.08: "gne",
	5.09: "gle",
	5.10: "gge",
	5.11: "precedes",
	5.12: "follows",
	5.13: "glt",
	5.14: "ggt",
	6: "concat",
	8.01: "add",
	8.02: "subtract",
	9.01: "multiply",
	10.02: "union",
	17.01: "plus",
	17.02: "minus",
	18: "map",
	19.01: "select",
	19.02: "select-all",
	20.01: "filter",
	20.03: "lookup",
	20.04: "array",
	20.07: "select-attribute"
};

declare variable $raddle:chars := $raddle:suffix || $raddle:ncname || "\$:%/#@\^";

declare variable $raddle:filter-regexp := "(\])|(,)?([^\[\]]*)(\[?)";
declare variable $raddle:operator-regexp := "=#\p{N}+#?\p{N}*=";
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

declare function raddle:escape-for-regex($map,$key) as xs:string {
	let $arg := $raddle:xq-operators($key)
	return
		if(matches($arg,"\p{L}+")) then
			if($arg = "if") then
				$arg || "\s*\("
			else if($arg = "then") then
				"\)\s*" || $arg
			else
				"\s" || $arg || "\s"
		else
			let $arg := replace($arg,"(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))","\\$1")
			return
				if($key = (8.02,17.02)) then
					"(^|\s)" || $arg || "(\s)?"
				else
					"\s?" || $arg || "\s?"

} ;

declare function raddle:map-put($map,$key,$val){
	map:new(($map,map {$key := $val}))
};

declare function raddle:parse-strings($strings as element()*,$params) {
	raddle:wrap(analyze-string(raddle:normalize-query(string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	})),$params),$raddle:paren-regexp)/fn:match,$strings)
};

declare function raddle:parse($query as xs:string?){
	raddle:parse($query,map {})
};

declare function raddle:parse($query as xs:string?,$params) {
	raddle:parse-strings(analyze-string($query,"'[^']*'")/*,$params)
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

declare function raddle:value-from-strings($val as xs:string?,$strings) {
	(: TODO replace :)
	if(matches($val,"\$%[0-9]+")) then
		concat("&quot;",raddle:clip-string($strings[number(replace($val,"\$%([0-9]+)","$1"))]),"&quot;")
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

declare function raddle:operator-precedence($string,$operator,$strings,$ret){
	let $rev := array:reverse($ret)
	let $last := array:head($rev)
	let $has-preceding-op := $last instance of map(xs:string?,item()?) and matches($last("name"),$raddle:operator-regexp)
	(: for unary operators :)
	let $is-unary-op := raddle:op-int($operator) = 8 and $has-preceding-op and $last("suffix") = false()
	let $operator :=
		if($is-unary-op) then
			raddle:unary-op($operator)
		else
			$operator
	let $val :=
		if(exists($string)) then
			raddle:value-from-strings($string,$strings)
		else
			()
	let $preceeds := $has-preceding-op and raddle:op-int($operator) > raddle:op-int($last("name"))
	let $name :=
		if($preceeds) then
			$last("name")
		else
			$operator
	let $args :=
		if($preceeds) then
			(: if operator > preceding swap the nesting :)
			let $argsize := array:size($last("args"))
			let $nargs :=
				if($is-unary-op) then
					[]
				else
					[$last("args")(2)]
			let $nargs :=
				if($val) then
					array:append($nargs,$val)
				else
					$nargs
			return if($argsize>1 and $is-unary-op) then
				let $pre := $last("args")(2)
				return [
					$last("args")(1),
					map {
						"name" := $pre("name"),
						"args" := array:append($pre("args"),map { "name" := $operator, "args" :=$nargs, "suffix" := ""}),
						"suffix" := ""
					}]
			else
				[$last("args")(1),map { "name" := $operator, "args" :=$nargs, "suffix" := ""}]
		else
			let $nargs := [$last]
			return
				if($val) then
					array:append($nargs,$val)
				else
					$nargs
	(: FIXME misuse of suffix for unary ops... :)
	return array:append(array:reverse(array:tail($rev)),map { "name" := $name, "args" := $args, "suffix" := exists($val)})
};

declare function raddle:append-prop-or-value($string,$operator,$strings,$ret) {
	if(matches($operator, $raddle:operator-regexp || "+")) then
		if(array:size($ret)>0) then
			raddle:operator-precedence($string,$operator,$strings,$ret)
		else
			array:append($ret,map { "name" := raddle:unary-op($operator), "args" := [raddle:value-from-strings($string,$strings)], "suffix" := ""})
	else
		array:append($ret,raddle:value-from-strings($string,$strings))
};

declare function raddle:to-op($opnum){
	if(map:contains($raddle:operator-map,$opnum)) then
		"n:" || $raddle:operator-map($opnum)
	else
		"n:" || replace($raddle:xq-operators($opnum)," ","-")
};

declare function raddle:unary-op($op){
	raddle:op-str(raddle:op-num($op) + 9)
};

declare function raddle:op-int($op){
	number(replace($op,"^=#(\p{N}+)#?\p{N}*=$","$1"))
};

declare function raddle:op-num($op){
	number(replace($op,"^=#(\p{N}+)#?(\p{N}*)=$","$1.$20"))
};

declare function raddle:op-str($op){
	concat("=#",replace(string($op),"\.","#"),"=")
};

declare function raddle:rename($a,$fn) {
	array:for-each($a,function($t){
		if($t instance of map(xs:string?,item()?)) then
			map {
				"name": $fn($t("name")),
				"args": raddle:rename($t("args"),$fn),
				"suffix": $t("suffix")
			}
		else
			$t
	})
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
			raddle:wrap($rest,$strings,raddle:append-prop-or-value($group[@nr=3]/string(),$group[@nr=2]/string(),$strings,$ret))
		else
			raddle:wrap($rest,$strings,$ret)
	else
		$ret
};

declare function raddle:wrap($match,$strings,$ret){
	raddle:wrap(tail($match),$strings,$ret,head($match)/fn:group)
};

declare function raddle:wrap($match,$strings){
	raddle:rename(raddle:wrap($match,$strings,[]),function($name){
		if(matches($name,$raddle:operator-regexp)) then
			raddle:to-op(raddle:op-num($name))
		else
			$name
	})
};

declare function raddle:normalize-filter($query as xs:string?) {
	if(matches($query,"^[\+\-]?\p{N}+$")) then (: TODO replace correct integers :)
		"position(.)=#5#07=" || $query
	else
		$query
};

declare function raddle:xq-seqtype($parts,$ret){
	let $maybe-seqtype := head($parts)/string()
	return
		if(matches($maybe-seqtype,"\{")) then
			$ret || "," || raddle:xq-body(tail($parts))
		else if(replace($maybe-seqtype,"\s","") = "as") then
			raddle:xq-seqtype(subsequence($parts,3),$parts[2]/string())
		else
			raddle:xq-seqtype(tail($parts),"item()")
};


declare function raddle:xq-params($parts,$ret,$i){
	let $maybe-param := head($parts)/fn:group[@nr=1]/string()
	let $maybe-param :=
		if(empty($maybe-param)) then
			head($parts)/string()
		else
			$maybe-param
	return
		if(matches($maybe-param,"\)")) then
			")," || raddle:xq-seqtype($parts,"item()")
		else if(matches($maybe-param,",")) then
			"," || raddle:xq-params(tail($parts),"",$i)
		else
			if(replace($parts[2]/string(),"\s","") = "as") then
				$parts[3]/string() || raddle:xq-params(for-each(subsequence($parts,4),function($p){
					if($p/fn:group[@nr=1]/string() = $maybe-param) then
						element fn:match {
							element fn:group {
								attribute { "nr" } { 1 },
								"$" || $i
							}
						}
					else
						$p
				}),"",$i+1)
			else if($parts[2]/string() = ",") then
				"," || raddle:xq-params(subsequence($parts,3),"",$i)
			else
				"item()" || raddle:xq-params(for-each(subsequence($parts,2),function($p){
					if($p/fn:group[@nr=1]/string() = $maybe-param) then
						element fn:match {
							element fn:group {
								attribute { "nr" } { 1 },
								"$" || $i
							}
						}
					else
						$p
				}),"",$i+1) (: or throw :)
};

declare function raddle:xq-fn($parts,$ret){
	(: TODO $parts(2) should be a paren, or error :)
	(: remove last } :)
	head($parts)/fn:group[@nr=1]/string() || ",(" || raddle:xq-params(subsequence($parts,3,count($parts)-3),"",1) || ")"
};

declare function raddle:xq-ns($parts,$ret){
	let $ns := replace(head($parts)/string(),"\s","")
	let $rest := tail($parts)
	return string-join($rest)
};

declare function raddle:xq-var($parts,$ret){
	let $ns := replace(head($parts)/string(),"\s","")
	let $rest := tail($parts)
	return string-join($rest)
};

declare function raddle:xq-annot($parts,$ret){
	let $maybe-annot := head($parts)/fn:group[@nr=1]/string()
	let $rest := tail($parts)
	return
		if(matches($maybe-annot,"^%")) then
			raddle:xq-annot($rest,$ret || $maybe-annot || "%")
		else if($maybe-annot = "function") then
			"define(" || $ret || raddle:xq-fn($rest,"")
		else if($maybe-annot = "variable") then
			"var(" || $ret || raddle:xq-var($rest,"")
		else ""
(:			raddle:xq-decl(($maybe-annot,$rest),""):)
};

declare function raddle:xq-decl($parts,$ret){
	let $type := head($parts)
	let $rest := tail($parts)
	return
		if($type = "function") then
			"define(" || raddle:xq-fn($rest,$ret) || ")"
		else if($type = "variable") then
			"var(" || raddle:xq-var($rest,$ret) || ")"
		else
			"ns(" || raddle:xq-ns($rest,"") || ")"
};

declare function raddle:xq-module($parts,$ret){
	let $head := head($parts)
	let $rest := tail($parts)
	return raddle:xq-block($rest,concat($ret,"(",$head/string(),")"))
};

declare function raddle:repl($lastseen as xs:float*,$no as xs:float){
	reverse(raddle:repl(reverse($lastseen),$no,()))
};

declare function raddle:repl($lastseen as xs:float*,$no as xs:float,$ret){
	if(count($lastseen)>0) then
		if(head($lastseen) eq $no - 0.01) then
			($ret, $no, tail($lastseen))
		else
			raddle:repl(tail($lastseen),$no,(head($lastseen),$ret))
	else
		$ret
};

declare function raddle:xq-body($parts){
	raddle:xq-body($parts,())
};

declare function raddle:xq-body($parts,$lastseen){
	let $head := head($parts)/fn:group[@nr=1]/string()
	let $head :=
		if(empty($head)) then
			head($parts)/string()
		else
			$head
	let $rest := tail($parts)
	let $next := head($rest)
	let $non :=
		if(matches($next,$raddle:operator-regexp)) then
			raddle:op-num($next)
		else
			()
	let $is-array := $non = 20.01 and matches(head($parts)/string(),"^(\s|\(|,)")
	let $rest :=
		if($is-array) then
			insert-before(tail($rest),1,element fn:match {
				element fn:group {
					attribute nr { 1 },
					raddle:op-str(20.04)
				}
			})
		else
			$rest
	return
		if(count($parts)>0) then
			if(matches($head,$raddle:operator-regexp)) then
				let $no := raddle:op-num($head)
				let $ret :=
					if($no = (2.06,2.09)) then
						concat(if(empty($lastseen)) then
							""
						else
							",",
						$head,"(")
					else if($no = (20.01,20.04)) then
						concat($head,"(")
					else if($no = (2.07,2.08,2.10)) then
						","
					else if($no = 20.02) then
						")"
					else
						$head
				let $ret :=
					if($no = 2.09) then
						concat($ret,replace($next/string(),"^\$|\s",""))
					else if($no = 20.01) then
						(: prepare filter :)
						concat($ret,raddle:normalize-filter($next/string()))
					else
						$ret
				let $rest :=
					if($no = (2.09, 20.01)) then
						tail($rest)
					else
						$rest
				let $lastseen :=
					if($no = (2.06,2.09)) then
						($lastseen,$no)
					else if($no = (2.07,2.08,2.10,2.11)) then
						raddle:repl($lastseen,$no)
					else
						$lastseen
				return
					concat($ret,raddle:xq-body($rest,$lastseen))
			else
				$head || raddle:xq-body($rest,$lastseen)
	else
		$head || string-join($lastseen ! ")")
};

declare function raddle:xq-block($parts,$ret){
	let $val := head($parts)/fn:group[@nr=1]/string()
	let $rest := tail($parts)
	return
			if($val eq "version") then
				raddle:xq-block($rest,$ret)
	(:			raddle:xq-version($rest,$ret):)
			else if($val eq "module") then
				raddle:xq-module($rest,$ret)
			else if($val eq "declare") then
				raddle:xq-annot($rest,$ret)
			else
				raddle:xq-body($parts)
};

declare function raddle:normalize-query($query as xs:string?,$params) {
	let $query := replace($query,"&#9;|&#10;|&#13;|%20"," ")
	let $query := replace($query,"%3A",":")
	let $query := replace($query,"%2C",",")
	let $query := replace($query,"%3C","<")
	let $query := replace($query,"%3E",">")
	(: TODO backwards support RQL, >= and <= will always be incompatible, use general comparisons instead :)
	(: normalize xquery :)
	(: prevent operator overwrites :)
	let $query := fold-left(map:keys($raddle:xq-operators),$query,function($cur,$next){
		if($next ne 1 and $next ne 5.07) then
			replace($cur,raddle:escape-for-regex($raddle:xq-operators,$next),raddle:op-str($next))
		else
			$cur
	})
	(: prevent = ambiguity :)
	let $query := replace($query,"=(#\p{N}+#?\p{N}*)=","%3D$1%3D")
	let $query := replace($query,"=","=#5#07=")
	let $query := replace($query,"%3D","=")
	let $query := replace($query,"(" || $raddle:operator-regexp || ")"," $1 ")
	let $query := replace($query,"\s+"," ")
	let $query := string-join(for-each(tokenize($query,";"),function($block){
		raddle:xq-block(analyze-string($block,"(?:^?)([^\s\(\),\.]+)(?:$?)")/*[name() = fn:match or matches(string(),"^\s*$") = false()],"")
	}),",")
	let $query := replace($query,"\s+","")
	(: TODO check if there are any ops left and either throw or fix :)
	return $query
};

declare function raddle:convert($string){
	if(matches($string,"^(\$.*)|([^#]+#[0-9]+)|(&quot;[^&quot;]*&quot;)$")) then
		$string
	else if(map:contains($raddle:auto-converted,$string)) then
		$raddle:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
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
					(: FIXME let hack :)
					let $fn :=
						if($qname = "n:let") then
							"let $" || raddle:clip-string($args(1)) || " := " || $args(2) || " return " || $args(3)
						else
							$qname || "(" || string-join(array:flatten($args),",") || ")"
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
					map:new(($def,map { "func" := raddle:compile($def("body"),$def,(),$params) }))
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
