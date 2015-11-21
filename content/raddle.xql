xquery version "3.1";

module namespace raddle="http://lagua.nl/lib/raddle";

declare variable $raddle:suffix := "\+\*\-\?";
declare variable $raddle:chars := $raddle:suffix || "\$:\w%\._\/#@\[\]\^";
declare variable $raddle:normalizeRegExp := concat("(\([",$raddle:chars,",]+\)|[",$raddle:chars,"]*|)([<>!]?=(?:[\w]*=)?|>|<)(\([",$raddle:chars,",]+\)|[",$raddle:chars,"]*|)");
declare variable $raddle:leftoverRegExp := concat("(\)[" || $raddle:suffix || "]?)|([&amp;\|,])?([",$raddle:chars,"]*)(\(?)");
declare variable $raddle:protocolRegexp := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$";
declare variable $raddle:primaryKeyName := 'id';
declare variable $raddle:jsonQueryCompatible := true();
declare variable $raddle:operatorMap := map {
	"=" := "eq",
	"==" := "eq",
	">" := "gt",
	">=" := "ge",
	"<" := "lt",
	"<=" := "le",
	"!=" := "ne"
};

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

declare function raddle:map-put($map,$key,$val){
	map:new(($map,map {$key := $val}))
};

declare function raddle:parse($query as xs:string?) {
	raddle:wrap(analyze-string(replace(replace($query,"&#10;|&#13;","")," ","%20"), $raddle:leftoverRegExp)/fn:match,[])
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
	raddle:get-index-from-tokens(for-each(tail($rest),function($_){
		if($_/fn:group[@nr=1]) then
			1
		else if($_/fn:group[@nr=4]) then
			-1
		else
			0
	}))[1]
};


declare function raddle:append-or-nest($next,$group,$ret,$suffix){
	if($group[@nr=3]) then
		array:append($ret,map { "name" := $group[@nr=3]/string(), "args" := raddle:wrap($next,[]), "suffix" := $suffix})
	else
		array:append($ret,raddle:wrap($next,[]))
};

declare function raddle:append-prop-or-value($group,$ret) {
	array:append($ret,$group[@nr=3]/string())
};

declare function raddle:wrap-open-paren($rest,$index,$group,$ret){
	raddle:wrap(subsequence($rest,$index),
		raddle:append-or-nest(subsequence($rest,1,$index),$group,$ret,replace($rest[$index - 1],"\)","")))
};

declare function raddle:wrap($match,$ret,$group){
	if(exists(tail($match))) then
		if($group[@nr=4]) then
			raddle:wrap-open-paren(tail($match),raddle:get-index($match),$group,$ret)
		else if($group[@nr=3] or $group[@nr=2]/string() = ",") then
			raddle:wrap(tail($match),raddle:append-prop-or-value($group,$ret))
		else
			raddle:wrap(tail($match),$ret)
	else
		$ret
};

declare function raddle:wrap($match,$ret){
	raddle:wrap($match,$ret,head($match)/fn:group)
};

declare variable $raddle:auto-converted := map {
	"true" := "true()",
	"false" := "false()",
	"null" := "()",
	"undefined" := "()",
	"Infinity" := "1 div 0e0",
	"-Infinity" := "-1 div 0e0"
};

declare function raddle:convert($string){
	if(matches($string,"^(\$.*)|([^#]*#[0-9]+)$")) then
		$string
	else if(matches($string,"'[^']*'")) then
		"&quot;" || substring(util:unescape-uri($string,"UTF-8"),2,string-length($string)-2) || "&quot;"
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
	let $groups := analyze-string($path,$raddle:protocolRegexp)//fn:group
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
				let $parsed := raddle:parse($src)
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
				raddle:map-put($arg,"args",array:insert-before($arg("args"),1,"function"))
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
			if(matches($key,"^\$.*")) then
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
					if(contains(array:flatten($_("args")),".")) then
						true()
					else
						()
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
	else
	if($value instance of array(item()?)) then
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

(:
declare function raddle:update-array($arr,$i,$val){
	let $arr := array:remove($arr,$i)
	return array:insert-before($arr,$i,$val)
};

declare function raddle:index-of($arr,$v){
	index-of(array:for-each($arr, function($_){
		if($_ = $v) then
			1
		else
			0
	}),1)
};
declare function raddle:compose($value){
	raddle:compose-helper($value, "", 0, array:size($value))
};

declare function raddle:compose-helper($value,$result,$argslen,$total){
	let $len := array:size($value)
	let $head := array:head($value)
	let $tail := array:tail($value)
	let $n := if($total=$len) then 0 else 1
	let $p := tokenize($head,"#")
	let $fn := $p[1]
	let $arity := xs:integer($p[2]) - $n
	let $a := for $i in 1 to $arity return "$arg" || ($i+$argslen)
	let $result := $fn || "(" || $result || (if($n=1 and $arity>0) then "," else "") || string-join($a,",") || ")"
	return
		if($len=1) then
			let $f := for $i in 1 to $total return "$f" || $i
			let $a := for $i in 1 to $arity+$argslen return "$arg" || $i
			return "function(" || string-join($a,",") || "){" || $result || "}"
		else
			raddle:compose-helper($tail,$result,$arity+$argslen, $total)
};
:)

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
	let $fname :=
		if(exists($parent)) then
(:			let $parity := if($parent("more")) then "N" else array:size($parent("args")):)
			$parent("qname")
		else
			"anon"
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
					else if(string($_) = ".") then
						"$arg0"
					else if(matches(string($_),"^\$[0-9]+$")) then
						replace($_,"^\$([0-9]+)$","\$arg$1")
					else
						raddle:convert($_)
				})
			return
				if($compose) then
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
	let $value := raddle:parse($str)
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