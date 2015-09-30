xquery version "3.1";

module namespace raddle="http://lagua.nl/lib/raddle";

declare variable $raddle:chars := "\+\*\$\-:\w%\._\/?#";
declare variable $raddle:normalizeRegExp := concat("(\([",$raddle:chars,",]+\)|[",$raddle:chars,"]*|)([<>!]?=(?:[\w]*=)?|>|<)(\([",$raddle:chars,",]+\)|[",$raddle:chars,"]*|)");
declare variable $raddle:leftoverRegExp := concat("(\))|([&amp;\|,])?([",$raddle:chars,"]*)(\(?)");
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

declare function raddle:parse($query as xs:string) {
	raddle:parse($query, ())
};

declare function raddle:get-index($close,$open,$ret){
	let $l := count($close)
	return
		if(empty($ret) and $l > 0) then
			let $ret :=
				for $i in 1 to $l return
					if($open[$i] < $close[$i]) then
						()
					else
						$close[$i]
			return raddle:get-index(tail($close),tail($open),$ret)
		else
			$ret
};

declare function raddle:wrap($analysis,$ret){
	let $x := head($analysis)
	let $closedParen := $x/fn:group[@nr=1]/text()
	let $delim := $x/fn:group[@nr=2]/text()
	let $propertyOrValue := $x/fn:group[@nr=3]/text()
	let $openParen := $x/fn:group[@nr=4]/text()
	let $rest := tail($analysis)
	return
		if($openParen) then
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
			let $index := raddle:get-index($close,$open,())[1]
			let $next := subsequence($rest,1,$index)
			let $ret := 
				if($propertyOrValue) then
					array:append($ret,map { "name" := $propertyOrValue, "args" := raddle:wrap($next,[])})
				else
					array:append($ret,raddle:wrap($next,[]))
			return raddle:wrap(subsequence($rest,$index,count($rest)),$ret)
		else if($closedParen) then
			raddle:wrap($rest,$ret)
		else if($propertyOrValue or $delim eq ",") then
			let $ret := array:append($ret,$propertyOrValue)
			return raddle:wrap($rest,$ret)
		else
			$ret
};

declare function raddle:parse($query as xs:string?, $parameters as xs:anyAtomicType?) {
	let $query:= raddle:normalize-query($query,$parameters)
	return if($query ne "") then
		let $analysis := analyze-string($query, $raddle:leftoverRegExp)
		let $ret := raddle:wrap($analysis/*,[])
		return $ret
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


declare function raddle:normalize-query($query as xs:string?, $parameters as xs:anyAtomicType?){
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
	if(contains($string,"#")) then
		$string
	else if(map:contains($raddle:auto-converted,$string)) then
		$raddle:auto-converted($string)
	else
		let $number := number($string)
		return
			if(string($number) = 'NaN') then
				"&quot;" || util:unescape-uri($string,"UTF-8") || "&quot;"
			else
				$number
};

declare variable $raddle:type-map := map {
	"any" := "xs:anyAtomicType",
	"element" := "element()"
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

declare function raddle:create-uri($path as xs:string, $params as item()*) as xs:string* {
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
			""
	let $path :=
		if($protocol = "xmldb:exist") then
			"/" || $path || "/" || $file
		else
			$path || "/" || $file
	let $uri :=
		if(empty($protocol)) then
			$params("raddled") || "/" || $path || $ext
		else
			$path || $ext
	(: TODO infer prefix: check if the remote location is a collection or document :)
	(: otherwise assume file has a 'module' declaration :)
	let $prefix :=
		if($ext eq "" and $protocol = ("","xmldb:exist") and util:binary-doc-available($uri)) then
			$file
		else
			$parts[last()]
	return ($uri,$prefix)
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
	let $mods := $value("args")
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	return
		map:new(
			array:flatten(
				array:for-each($mods,function($_){
					let $uri := raddle:create-uri($_,$params)
					let $path := $uri[1]
					let $src := util:binary-to-string(util:binary-doc($path))
					let $parsed := raddle:parse($src)
					let $main := tokenize($_,"/")[1]
					let $prefix := if(exists($map[@name = $main])) then
							string($map[@name = $main]/@prefix)
						else
							$uri[2]
					return raddle:process($parsed,map:new(($params,map {"use" := $prefix})))
				})
			)
		)
};

declare function raddle:process($value,$params){
	let $mod := 
		array:filter($value,function($arg){
			$arg("name")="module"
		})
	let $use := 
		array:filter($value,function($arg){
			$arg("name")="use"
		})
	let $define := 
		array:filter($value,function($arg){
			$arg("name")="define"
		})
	let $compile := 
		array:filter($value,function($arg){
			not($arg("name") = ("use","define","module"))
		})
	let $dict := 
		map:new(($params("dict"),
			for $i in 1 to array:size($use) return
				raddle:use($use($i),$params)
		))
	let $dict := 
		map:new(($dict,
			for $i in 1 to array:size($define)
				let $def := raddle:define($define($i),$params)
				return map:entry($def("qname"),$def)
		))
	let $func :=
		if(array:size($compile)>0) then
			raddle:compile($compile,(),(),map:new(($params,map { "top" := true() })))
		else
			()
	return
		(: TODO add module info to dictionary :)
		if(array:size($mod)>0) then
			let $module := raddle:module($mod(1),$params)
			let $modstr := raddle:create-module($dict,map:new(($params,map { "module" := $module})))
			return map:new(($dict, map:new(map:entry($module("prefix"),map:new(($module,map { "func" := $modstr }))))))
		else
			map:new(($dict, map { "anon:top#1" := map { "name":="top","qname":="anon:top#1","body":=$compile,"func":=$func }}))
};

declare function raddle:create-module($dict,$params){
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	let $mods :=
		for $key in map:keys($dict) return
			if(matches($key,"^local:|^anon:")) then
				()
			else
				$dict($key)("prefix")
	let $module :=
		if(map:contains($params,"module")) then
			$params("module")
		else
			()
	let $import := 
		for $ns in distinct-values($mods) return
			if($ns) then
				let $entry := $map[@prefix = $ns]
				return
					if($entry/@location) then
						"import module namespace " || $ns || "=&quot;" || $entry/@uri || "&quot; at &quot;" || $entry/@location || "&quot;;"
					else
						if(not(exists($module)) or $module("prefix") ne $ns) then
							"declare namespace " || $ns || "=&quot;" || $entry/@uri || "&quot;;"
						else
							()
			else
				()
	let $local := 
		for $key in map:keys($dict) return
			if((exists($module) and starts-with($key,$module("prefix") || ":")) or matches($key,"^local:")) then
				"declare function " || $dict($key)("qname") || substring($dict($key)("func"),9,string-length($dict($key)("func"))) || ";"
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
			"module namespace " || $module("prefix") || "=&quot;" || $module("uri") || "&quot;;&#xa;"
		else
			()
	return "xquery version &quot;3.1&quot;;&#xa;" || $moduledef || string-join(($import,$local,$anon),"&#xa;")
};

declare function raddle:store-module($dict,$params) {
	if(map:contains($params,"module")) then
		let $def := $params("module")
		let $location := $def("location")
		let $coll := replace($location, "^(.*)/[^/]+/?$", "$1")
		let $name := replace($location, "^.*/([^/]+)$", "$1")
		let $mod := raddle:create-module($dict,$params)
		let $store := xmldb:store($coll,$name,$mod,"application/xquery")
		return "Module successfully stored to: " || $store
	else
		"No module definition found in params"
};

declare function raddle:eval($dict,$params){
	let $str := raddle:create-module($dict,$params)
	return util:eval($str)
};

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

declare function raddle:get-seq-type($value) {
	if(array:size($value) eq 0) then
		3
	else
		let $type := distinct-values(array:flatten(
			array:for-each($value,function($_){
				if($_ instance of map(xs:string, item()?) or $_ instance of array(item()?)) then
					1
(:				else if(contains($_,"#")) then:)
(:					2:)
				else if(contains($_,":")) then
					2
				else
					3
			})
		))
		return
			if(count($type)>1) then
				error(xs:QName("raddle:sequenceTypeError"), "Mixing sequence types is not allowed" || $type)
			else
				$type
};

declare function raddle:serialize($value){
	if($value instance of map(xs:string, item()?)) then
		"map {" || string-join(map:for-each-entry($value,function($key,$val){
			"&quot;" || $key || "&quot; := " || raddle:serialize($val)
		}),",") || "}"
	else if($value instance of array(item()?)) then
		"[" || string-join(array:flatten(array:for-each($value,function($val){
			raddle:serialize($val)
		})),",") || "]"
	else
		raddle:convert($value)
};

(: 
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
	let $result := $fn || "("  || $result || (if($n=1 and $arity>0) then "," else "") || string-join($a,",") || ")"
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
	let $seqType :=
		if($isSeq) then
			raddle:get-seq-type($value)
		else
			0
	let $ret :=
		if($isSeq) then
			if($seqType = 1) then
				local:fold-left($value,"",function($pre,$cur,$i){
					if($cur instance of map(xs:string, item()?)) then
						(: compose the functions in the array :)
						let $c := raddle:compile($cur,(),true(),$params)
						let $p :=
							if(array:size($c)>1) then
								tokenize($c(2),",")
							else
								()
						 let $p :=
							if(exists($parent) and count($p)>0 and $p[1] = "$arg0") then
								remove($p,1)
							else
								$p
						 let $t :=
							if(count($p) > 0 and $i > 0) then
								","
							else
								""
						 return $c(1) || $pre || $t || string-join($p,",") || ")"
					else
						""
				})
			else if($seqType = 2) then
				array:fold-left($value,map {},function($pre,$cur){
					let $p := tokenize($cur,":")
					return map:new(($pre,map:entry($p[1],$p[2])))
				})
			else
				$value
		else
			()
	let $fargs :=
		if(exists($parent)) then
			string-join((for $i in 1 to array:size($parent("args")) return
				let $type := $parent("args")($i)
				let $stype := replace($type,"\*|\+","")
				let $xsd := 
					if(map:contains($raddle:type-map,$stype)) then
						replace($type,$stype,map:get($raddle:type-map,$stype))
					else
						"xs:" || $stype
				return "$arg" || $i || " as " || $xsd
			),",")
		else
			"$arg0"
	let $fname :=
		if(exists($parent)) then
(:		  let $parity := if($parent("more")) then "N" else array:size($parent("args")):)
			 $parent("qname")
		else
			"anon"
	return
		if($isSeq) then
			if($seqType = 1) then
				"function(" || $fargs || "){" || $ret || "}"
			else
				(: stringify :)
				raddle:serialize($ret)
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
					else if(matches(string($_),"^(\./)|\.$")) then
						$_
					else if(matches(string($_),"^\$[0-9]+$")) then
						replace($_,"^\$([0-9]+)$","\$arg$1")
					else
						raddle:convert($_)
				})
			let $args2 :=
				local:fold-left($args,[$qname || "("],function($pre,$cur,$i){
					if(matches($cur,"^(\./)|\.$")) then
						array:append($pre,"$arg0")
					else
						let $s := array:size($pre)
						let $last := $pre($s)
						return
							if(matches($last,"^(\./)|\.$") or $s<2) then
								array:append($pre,$cur)
							else
								array:append(array:remove($pre,$s),$last || "," || $cur)
				})
			return
				if($compose) then
					$args2
				else
					let $args2 := array:append($args2,")")
					let $args2 := array:flatten($args2)
					let $fn := string-join($args2,"")
					return 
						if(exists($parent) or $top) then
							"function(" || $fargs || "){ " || $fn || "}"
						else
							$fn
};

declare function raddle:define($value,$params){
	let $l := array:size($value("args"))
	let $name := $value("args")(1)
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
			let $ns :=
				if($l=3) then
					$params("use")
				else if(count($parts)>1) then
					$parts[1]
				else
					"local"
			let $qname :=
				if(contains($name,":")) then
					$name
				else
					if($ns) then
						$ns || ":" || $name
					else
						$name
			let $def :=
				if(map:contains($params("dict"),$qname)) then
					map:get($params("dict"),$qname)
				else
					map {
						"qname" := $qname,
						"arity" := $arity,
						"prefix" := $ns,
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