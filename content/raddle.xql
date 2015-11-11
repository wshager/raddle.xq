xquery version "3.1";

module namespace raddle="http://lagua.nl/lib/raddle";

declare variable $raddle:suffix := "\+\*\-\?";
declare variable $raddle:chars := $raddle:suffix || "\$:\w%\._\/#@";
declare variable $raddle:normalizeRegExp := concat("(\([",$raddle:chars,",]+\)|[",$raddle:chars,"]*|)([<>!]?=(?:[\w]*=)?|>|<)(\([",$raddle:chars,",]+\)|[",$raddle:chars,"]*|)");
declare variable $raddle:leftoverRegExp := concat("(\)[" || $raddle:suffix || "]?)|([&amp;\|,])?([",$raddle:chars,"]*)(\(?)");
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

declare function local:fold-left($array as array(*), $acc, $fn as function(*)) {
	local:fold-left($array, $acc, $fn, array:size($array))
};

declare function local:fold-left($array as array(*), $acc, $fn as function(*), $total as xs:integer) {
	let $i := array:size($array)
	return
		if($i = 0) then
			$acc
		else
			local:fold-left(array:tail($array), $fn($acc,array:head($array),$total - $i), $fn, $total)
};

declare function raddle:map-put($map,$key,$val){
	map:new(($map,map {$key := $val}))
};

declare function raddle:parse($query as xs:string) {
	raddle:parse($query, ())
};

declare function raddle:get-index($rest,$ret){
	let $close :=
		for $i in 1 to count($rest) return 
			if($rest[$i]/fn:group[@nr=1]/text()) then
				$i
			else
				()
	let $open :=
		for $i in 1 to count($rest) return 
			if($rest[$i]/fn:group[@nr=4]/text()) then
				$i
			else
				()
	let $l := count($close)
	return
		if(empty($ret) and $l > 0) then
			let $ret :=
				for $i in 1 to $l return
					if($open[$i] < $close[$i]) then
						()
					else
						$close[$i]
			return raddle:get-index(tail($rest),$ret)
		else
			$ret
};

declare function raddle:wrap($analysis,$strings,$ret){
	raddle:wrap($analysis,$strings,$ret,"")
};

declare function raddle:wrap($analysis,$strings,$ret,$suffix){
	let $x := head($analysis)
	let $closedParen := $x/fn:group[@nr=1]/text()
	let $delim := $x/fn:group[@nr=2]/text()
	let $propertyOrValue := $x/fn:group[@nr=3]/text()
	let $openParen := $x/fn:group[@nr=4]/text()
	let $rest := tail($analysis)
	let $ret :=
		if($suffix ne "" and array:size($ret)>0) then
			let $retr := array:reverse($ret)
			let $body := array:reverse(array:tail($retr))
			let $last := array:head($retr)
			let $last := if($last instance of map(xs:string,item()*)) then
				raddle:map-put($last,"suffix",$suffix)
			else
				$last
			return
				array:append($body,$last)
		else
			$ret
	return
		if($openParen) then
			let $index := raddle:get-index($rest,())[1]
			let $next := subsequence($rest,1,$index)
			let $ret := 
				if($propertyOrValue) then
					let $val :=
						if(matches($propertyOrValue,"\$s")) then
							$strings[number(replace($propertyOrValue,"\$s",""))]/string()
						else
							$propertyOrValue
					return array:append($ret,map { "name" := $val, "args" := raddle:wrap($next,$strings,[])})
				else
					array:append($ret,raddle:wrap($next,$strings,[]))
			return raddle:wrap(subsequence($rest,$index,count($rest)),$strings,$ret)
		else if($closedParen) then
			raddle:wrap($rest,$strings,$ret,replace($closedParen,"\)",""))
		else if($propertyOrValue or $delim eq ",") then
			let $val :=
				if(matches($propertyOrValue,"\$s")) then
					$strings[number(replace($propertyOrValue,"\$s",""))]/string()
				else
					$propertyOrValue
			let $ret := array:append($ret,$val)
			return raddle:wrap($rest,$strings,$ret)
		else
			$ret
};

declare function raddle:parse($query as xs:string?, $parameters as item()*) {
	let $strings := analyze-string($query, "'[^']*'")/*
	let $query := string-join(for $i in 1 to count($strings) return
		if(name($strings[$i]) eq "match") then
			"$s" || $i
		else
			$strings[$i]/string())
	let $query:= raddle:normalize-query($query)
	return if($query ne "") then
		raddle:wrap(analyze-string($query, $raddle:leftoverRegExp)/fn:match,$strings,[])
	else
		[]
};

declare function raddle:no-conjunction($seq,$hasopen) {
	if($seq[1]/text() eq ")") then
		if($hasopen) then
			raddle:no-conjunction(subsequence($seq,2,count($seq)),false())
		else
			$seq[1]
	else if($seq[1]/text() = ("&amp;", "|")) then
		false()
	else if($seq[1]/text() eq "(") then
		raddle:no-conjunction(subsequence($seq,2,count($seq)),true())
	else
		false()
};

declare function raddle:set-conjunction($query as xs:string) {
	let $parts := analyze-string($query,"(\()|(&amp;)|(\|)|(\))")/*
	let $groups := 
		for $i in 1 to count($parts) return
			if(name($parts[$i]) eq "non-match") then
				element group {
					$parts[$i]/text()
				}
			else
			let $p := $parts[$i]/fn:group/text()
			return
				if($p eq "(") then
						element group {
							attribute i {$i},
							$p
						}
				else if($p eq "|") then
						element group {
							attribute i {$i},
							$p
						}
				else if($p eq "&amp;") then
						element group {
							attribute i {$i},
							$p
						}
				else if($p eq ")") then
						element group {
							attribute i {$i},
							$p
						}
				else
					()
	let $cnt := count($groups)
	let $remove :=
		for $n in 1 to $cnt return
			let $p := $groups[$n]
			return
				if($p/@i and $p/text() eq "(") then
					let $close := raddle:no-conjunction(subsequence($groups,$n+1,$cnt)[@i],false())
					return 
						if($close) then
							(string($p/@i),string($close/@i))
						else
							()
				else
					()
	let $groups :=
		for $x in $groups return
			if($x/@i = $remove) then
				element group {$x/text()}
			else
				$x
	let $groups :=
		for $n in 1 to $cnt return
			let $x := $groups[$n]
			return
				if($x/@i and $x/text() eq "(") then
					let $conjclose :=
						for $y in subsequence($groups,$n+1,$cnt) return
							if($y/@i and $y/text() = ("&amp;","|",")")) then
								$y
							else
								()
					let $t := $conjclose[text() = ("&amp;","|")][1]
					let $conj :=
						if($t/text() eq "|") then
							"or"
						else
							"and"
					let $close := $conjclose[text() eq ")"][1]/@i
					return
						element group {
							attribute c {$t/@i},
							attribute e {$close},
							concat($conj,"(")
						}
				else if($x/text() = ("&amp;","|")) then
					element group {
						attribute i {$x/@i},
						attribute e {10e10},
						attribute t {
							if($x/text() eq "|") then
								"or"
							else
								"and"
						},
						","
					}
				else
					$x
	let $groups :=
		for $n in 1 to $cnt return
			let $x := $groups[$n]
			return
				if($x/@i and not($x/@c) and $x/text() ne ")") then
					let $seq := subsequence($groups,1,$n - 1)
					let $open := $seq[@c eq $x/@i]
					return
						if($open) then
							element group {
								attribute s {$x/@i},
								attribute e {$open/@e},
								","
							}
						else
							$x
				else
					$x
	let $groups :=
		for $n in 1 to $cnt return
			let $x := $groups[$n]
			return
				if($x/@i and not($x/@c) and $x/text() ne ")") then
					let $seq := subsequence($groups,1,$n - 1)
					let $open := $seq[@c eq $x/@i][last()]
					let $prev := $seq[text() eq ","][last()]
					let $prev := 
							if($prev and $prev/@e < 10e10) then
								$seq[@c = $prev/@s]/@c
							else
								$prev/@i
					return
						if($open) then
							$x
						else
							element group {
								attribute i {$x/@i},
								attribute t {$x/@t},
								attribute e {$x/@e},
								attribute s {
									if($prev) then
										$prev
									else
										0
								},
								","
							}
				else
					$x
	let $groups :=
			for $n in 1 to $cnt return
				let $x := $groups[$n]
				return
					if($x/@i or $x/@c) then
						let $start := $groups[@s eq $x/@i] | $groups[@s eq $x/@c]
						return
							if($start) then
								element group {
									$x/@*,
									if($x/@c) then
										concat($start/@t,"(",$x/text())
									else
										concat($x/text(),$start/@t,"(")
								}
							else
								$x
					else
						$x
	let $pre := 
		if(count($groups[@s = 0]) > 0) then
			concat($groups[@s = 0]/@t,"(")
		else
			""
	let $post := 
		for $x in $groups[@e = 10e10] return
			")"
	return concat($pre,string-join($groups,""),string-join($post,""))
};


declare function raddle:normalize-query($query as xs:string?){
	let $query :=
		if(not($query)) then
			""
		else
			replace(replace($query,"&#10;|&#13;","")," ","%20")
	let $query := replace($query,"%3A",":")
	let $query := replace($query,"%2C",",")
	let $query :=
		if($raddle:jsonQueryCompatible) then
			let $query := replace($query,"%3C=","=le=")
			let $query := replace($query,"%3E=","=ge=")
			let $query := replace($query,"%3C","=lt=")
			let $query := replace($query,"%3E","=gt=")
			return $query
		else
			$query
	(: convert FIQL to normalized call syntax form :)
	let $analysis := analyze-string($query,$raddle:normalizeRegExp)
	
	let $analysis :=
		for $x in $analysis/* return
			if(name($x) eq "non-match") then
				$x
			else
				let $property := $x/fn:group[@nr=1]/text()
				let $operator := $x/fn:group[@nr=2]/text()
				let $value := $x/fn:group[@nr=3]/text()
				let $operator := 
					if(string-length($operator) < 3) then
						if(map:contains($raddle:operatorMap,$operator)) then
							$raddle:operatorMap($operator)
						else
							(:throw new URIError("Illegal operator " + operator):)
							()
					else
						substring($operator, 2, string-length($operator) - 2)
				return concat($operator, "(" , $property , "," , $value , ")")
	let $query := string-join($analysis,"")
	return raddle:set-conjunction($query)
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
		"&quot;" || substring($string,2,string-length($string)-2) || "&quot;"
	else if(map:contains($raddle:auto-converted,$string)) then
		$raddle:auto-converted($string)
	else
		let $number := number($string)
		return
			if(string($number) = 'NaN') then
				"&quot;" || $string || "&quot;"
			else
				$number
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

declare function raddle:create-uri($path as xs:string, $params as item()*) {
	let $regex := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$"
	let $groups := analyze-string($path,$regex)//fn:group
	let $protocol := $groups[@nr = 2]/text()
	let $parts := tokenize($groups[@nr = 3]/text(),"/")
	let $file := $parts[last()]
	let $parts := subsequence($parts,1,count($parts)-1)
	let $path := string-join($parts,"/")
	let $ext := replace($file,"^.*(\.\w+)|([^.]*)$","$1")
	let $ext :=
		if($ext eq "") then
			".rdl"
		else
			$ext
	let $uri :=
		(
			if(empty($protocol)) then
				$params("raddled") || "/"
			else if($protocol = "xmldb:exist") then
				"/"
			else
				""
		) || $path || (if($path eq "") then "" else "/") || $file || $ext
	(: TODO add parent for partial modules :)
	return map {
		"location" := $uri,
		"collection":= $path,
		"parent" := $parts[last()],
		"file" := $file,
		"ext" := $ext
	}
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
				return raddle:process($parsed,map:new(($params,map {"use" := $uri})))
			})
		)
	)
};

declare function raddle:process($value,$params){
	let $compile := 
		array:filter($value,function($arg){
			not($arg instance of map(xs:string*,item()?) and $arg("name") = ("use","define","module","declare"))
		})
	let $value :=
		array:filter($value,function($arg){
			$arg instance of map(xs:string*,item()?) and $arg("name") = ("use","define","module","declare")
		})
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
		map:new(($params("dict"),
			for $i in 1 to array:size($use) return
				raddle:use($use($i),$params)
		))
	let $dict := 
		map:new(($dict,
			for $i in 1 to array:size($declare)
				let $def := raddle:declare($declare($i),$params)
				return map:entry($def("qname"),$def)
		))
	let $func :=
		if(array:size($compile)>0) then
			raddle:compile($compile(1),(),(),map:new(($params,map { "top" := true() })))
		else
			()
	return
		(: TODO add module info to dictionary :)
		if(array:size($mod)>0) then
			raddle:insert-module($dict,$params)
		else if(array:size($compile)>0) then
			map:new(($dict, map { "anon:top#1" := map { "name":="top","qname":="anon:top#1","body":=$compile,"func":=$func }}))
		else $dict
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
	return "xquery version &quot;3.1&quot;;&#xa;" || $moduledef || string-join(($import,$local,$anon),"&#xa;")
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
					true()
				else
					false()
			})
		))
		return
			if(count($type)>1) then
				error(xs:QName("raddle:sequenceTypeError"), "Mixing sequence types is not allowed" || $type)
			else
				$type
};

declare function raddle:serialize($value){
	raddle:serialize($value,true())
};

declare function raddle:serialize($value,$convert){
	if($value instance of map(xs:string, item()?)) then
		$value("name") || (if(map:contains($value,"args")) then raddle:serialize($value("args"),$convert) else "()") || (if(map:contains($value,"suffix")) then $value("suffix") else "")
	else
	if($value instance of array(item()?)) then
		"(" || string-join(array:flatten(array:for-each($value,function($val){
			raddle:serialize($val,$convert)
		})),",") || ")"
	else
		if($convert) then
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

declare function raddle:compile($value,$parent,$compose,$params){
	let $top := $params("top")
	let $params := map:remove($params,"top")
	let $isSeq := $value instance of array(item()?)
	return
		if(not($isSeq or $value instance of map(xs:string, item()?))) then
			raddle:serialize($value)
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
						let $args := array:flatten(array:tail($c))
						let $args := 
							if(count($args) > 1 and $pre ne "") then
								let $index := index-of($args,"$arg0")
								let $args := remove($args,$index)
								return insert-before($args,$index,$pre)
							else
								$args
						return $qname || "(" || string-join($args,",") || ")"
					else
						""
				})
			else
				$value
		else
			()
	let $fargs :=
		if(exists($parent)) then
			string-join((for $i in 1 to array:size($parent("args")) return
				let $type := $parent("args")($i)
				let $xsd :=  
					if($type instance of map(xs:string, item()?)) then
						raddle:serialize($type,false())
					else
						let $stype := replace($type,"[" || $raddle:suffix || "]?$","")
						return
							(if(map:contains($raddle:type-map,$stype)) then
								replace($stype,$stype,map:get($raddle:type-map,$stype))
							else
								$stype) || replace($type,"^[^" || $raddle:suffix || "]*","")
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
				(: stringify :)
				let $ret := raddle:serialize($ret)
				return
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
		case "namespace" return ()
		default return raddle:define(map{"args":=$args},$params)
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
			let $def := $params("dict")($name)
			let $arity := array:size($def("args"))
			return map:new(($def,map:entry("qname",$name || "#" || $arity)))
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