xquery version "3.1";

module namespace raddle="http://lagua.nl/lib/raddle";
import module namespace json="http://www.json.org";


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
	if(map:contains($raddle:auto-converted,$string)) then
		$raddle:auto-converted($string)
	else
		let $number := number($string)
		return
			if(string($number) = 'NaN') then
				"'" || util:unescape-uri($string,"UTF-8") || "'"
			else
				$number
};

declare function raddle:use($value,$params){
	let $mods := $value("args")
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	let $main := distinct-values(array:for-each($mods,function($_){
		tokenize($_,"/")[1]
	}))
	let $reqs := for-each($main,function($_){
		let $location := xs:anyURI($map[@name = $_]/@location)
		let $uri := xs:anyURI($map[@name = $_]/@uri)
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
	})
	return
		map:new(
			array:flatten(
				array:for-each($mods,function($_){
					let $src := util:binary-to-string(util:binary-doc($params("raddled") || "/" || $_ || ".rdl"))
					let $parsed := raddle:parse($src)
					let $main := tokenize($_,"/")[1]
					let $prefix := string($map[@name = $main]/@prefix)
					return raddle:process($parsed,map:new(($params,map {"use" := $prefix})))
				})
			)
		)
};

declare function raddle:process($value,$params){
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
			not($arg("name") = ("use","define"))
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
	let $func := raddle:compile($compile,(),(),$params)
	return map:new(($dict, map { "anon:top#1" := map { "name":="top","qname":="anon:top#1","body":=$compile,"func":=$func }}))
};

declare function raddle:eval($dict,$params){
	let $str :=
		for $key in map:keys($dict) return
			if(matches($key,"^raddle:")) then
				"declare function raddle:" || $dict($key)("name") || substring($dict($key)("func"),9,string-length($dict($key)("func"))) || ";"
			else if(matches($key,"^anon:")) then
				$dict($key)("func")
			else
				 ()
	return util:eval("xquery version &quot;3.1&quot;;" || string-join($str,"&#13;"))
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

declare function raddle:inc-replace($arr,$acc){
	if(array:size($arr)>0) then
		let $i := $acc(1)
		let $a := $acc(2)
		let $v := array:head($arr)
		let $inc := 
			if($v = "?") then
					1
				else
					0
		let $v :=
			if($inc = 1) then
				"$arg" || $i
			else
				$v
		let $a := array:append($a,$v)
		return
				raddle:inc-replace(array:tail($arr),[$i+$inc,$a])
	else
		$acc
};

declare function raddle:seq-inc-replace($arr,$acc) {
	if(array:size($arr)>0) then
		let $i := $acc(1)
		let $a := $acc(2)
		let $v := array:head($arr)
		let $nacc := raddle:inc-replace($v(2),[$i,[]])
		let $ni := $nacc(1)
		let $na := array:append($a,$nacc(2))
		return
			raddle:seq-inc-replace(array:remove($arr,1),[$ni,$na])
	else
		$acc
};
declare function raddle:compile($value,$parent,$pa,$params){
	let $arity :=
		if(count($parent)) then
			$parent("arity")
		else
			0
	let $a :=
		for $i in 1 to $arity - 1 return "$arg" || $i
	let $fa := subsequence($a,1)
	(: always compose :)
	let $value :=
		if($value instance of array(item()?)) then
			   $value
		   else
			   array { $value }
	(: compose the functions in the value array :)
	let $f := array:for-each($value,function($v){
		let $acc := []
		let $arity := array:size($v("args"))
		let $name := $v("name")
		let $qname := concat($name,"#",$arity)
		let $acc := array:append($acc,$qname)
		let $args := 
			array:for-each($v("args"),function($_){
				if($_ = (".","?")) then
					$_
				else if($_ instance of array(item()?)) then
					raddle:compile($_,(),$a,$params)
				else
					raddle:convert($_)
			})
		(: return map:new(($v,map:entry("args",$args))):)
		return array:append($acc,$args)
	})
	let $f:= raddle:seq-inc-replace($f,[1,[]])(2)
	(: TODO get exec :)
	let $exec := ()
	(:let $fn := array:fold-left($f,"$arg0",function($pre,$cur){
		let $f := $cur(1)
		let $args := $cur(2)
		let $rpl := (string(array:head($args)) = ".")
		let $args :=
			if($rpl) then
				insert-before(array:flatten(array:tail($args)),1,$pre)
			else
				array:flatten($args)
		return
		  if($rpl) then
			  "apply(" || $f || ",[" || string-join($args,",") || "])"
		  else
			  "(" || $pre || ", apply(" || $f || ",[" || string-join($args,",") || "]))"
	})
	let $fargs := string-join(insert-before($fa,1,"$arg0"),",")
	let $func := "function(" || $fargs || "){ " || $fn || "}"
	:)
	(:if(!$exec or $top) then
		$func
	else
		$func || "(())"
	:)
	return $f
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
			let $qname := $qname || "#" || $arity
			let $def :=
				if(map:contains($params("dict"),$qname)) then
					map:get($params("dict"),$qname)
				else
					map {
						"name" := $name,
						"qname" := $qname,
						"arity" := $arity,
						"ns" := $ns,
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