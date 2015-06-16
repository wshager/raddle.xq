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

declare function raddle:get-index($close,$open){
    for $i in 1 to count($close) return
        if($open[$i] < $close[$i]) then
            raddle:get-index(tail($close),tail($open))
        else
            $close[$i]
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
            let $index := raddle:get-index($close,$open)[1]
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

declare function local:no-conjunction($seq,$hasopen) {
    if($seq[1]/text() eq ")") then
        if($hasopen) then
            local:no-conjunction(subsequence($seq,2,count($seq)),false())
        else
            $seq[1]
    else if($seq[1]/text() = ("&amp;", "|")) then
        false()
    else if($seq[1]/text() eq "(") then
        local:no-conjunction(subsequence($seq,2,count($seq)),true())
    else
        false()
};

declare function local:set-conjunction($query as xs:string) {
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
                    let $close := local:no-conjunction(subsequence($groups,$n+1,$cnt)[@i],false())
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
            replace($query," ","%20")
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
    return local:set-conjunction($query)
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
            if(string($number) ne 'NaN') then
                util:unescape-uri($string,"UTF-8")
                (:if(exports.jsonQueryCompatible){
                    if(string.charAt(0) == "'" && string.charAt(string.length-1) == "'"){
                        return JSON.parse('"' + string.substring(1,string.length-1) + '"');
                    }
                }):)
            else
                $number
};

declare function raddle:use($value,$params){
	let $mods := $value("args")
	let $map := doc($params("raddled") || "/map.xml")/root/module
	let $reqs := array:for-each($mods,function($_){
		let $uri := xs:anyURI($map[@rdl = $_]/@xq)
		let $module := inspect:inspect-module-uri($uri)
		return try {
			util:import-module(xs:anyURI($module/@uri), $module/@prefix, xs:anyURI($module/@location))
		} catch * {
			()
		}
	})
	return array:for-each($mods,function($_){
		let $src := util:binary-doc($params("raddled") || "/raddled/" || $_ || ".rdl")
		let $parsed := raddle:parse($src)
		return
			if(array:size($parsed("args")) > 0) then
				raddle:process($parsed,map:new(($params,map {"use" := $_})))
			else
				()
	})
};

declare function raddle:process($value,$params){
    if($value instance of array(item()?)) then
        array:for-each($value,function($_) {
            raddle:process($_,$params)
        })
	else if($value("name") = "use") then
		raddle:use($value,$params)
	else if($value("name") = "define") then
		raddle:define($value,$params)
	else if(not($value("name")) and map:contains($value,"args")) then
		let $use := 
			array:filter($value("args"),function($arg){
				$arg("name")="use"
			})
		let $define := 
			array:filter($value("args"),function($arg){
				$arg("name")="define"
			})
		let $process := 
			array:filter($value("args"),function($arg){
				not($arg("name") = ("use","define"))
			})
		return
			(
				array:for-each($use,function($_) { raddle:use($_,$params) }),
				array:for-each($define,function($_) { raddle:define($_,$params) }),
				array:for-each($process,function($_) { raddle:process($_,$params) })
			)
				
	else
		raddle:compile(map {}, map:new(($value, map { "top" := true() })),(),())
};


declare function raddle:compile($dict,$value,$parent,$pa){
    let $arity :=
        if($parent) then
            array:size($parent("args"))
        else
            0
    let $a :=
        for $i in 1 to $arity return "$arg" || $i
    let $fa := subsequence($a,2)
    let $fargs := string-join($fa,",")
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
        let $aname := concat($name,"#",$arity)
        let $def := $dict($aname)
        let $acc := array:append($acc,$aname)
        let $args := array:for-each($v("args"),function($_){
            if($_ = (".","?")) then
                $_
            else if($_ instance of array(item()?)) then
                raddle:compile($dict,$_,(),$a)
            else
                raddle:convert($_)
        })
        return array:append($acc,$args)
    })
    (: TODO get exec :)
    let $exec := ()
    let $fn := array:fold-left($f,"$arg0",function($pre,$cur){
      let $f := $cur(1)
      let $args := $cur(2)
      let $args :=
          if(string(array:head($args)) = ".") then
              array:insert-before(array:tail($args),1,$pre)
          else
              $args
      return
          if(string(array:head($args)) = ".") then
              "apply(" || $f || ",[" || string-join(array:flatten($args),",") || "])"
          else
              "(" || $pre || ", apply(" || $f || ",[" || string-join(array:flatten($args),",") || "]))"
    })
    let $fargs := string-join(insert-before($fa,1,"$arg0"),",")
    let $func := "function(" || $fargs || "){ " || $fn || "}"
    (:if(!$exec or $top) then
        $func
    else
        $func || "(())"
    :)
    return $func
};


declare function raddle:define($value,$params){
	let $l := array:size($value("args"))
	let $name := $value("args")(1)
	let $parts := tokenize($name,":")
	let $ns :=
		if(count($parts)>1) then
			$parts[1]
		else
			()
	let $def :=
		if($l=2) then
			let $def := $params("dict")($name)
			let $arity := array:size($def("args"))
			return map:new(($def,map:entry("qname",$name || "#" || $arity)))
		else
			let $args := $value("args")(2)
			let $arity := array:size($args)
			let $type := $value("args")(3)
			let $ns :=
				if($ns) then
					$ns
				else if($l=3) then
					"local"
				else
					tokenize($params("use"),"/")[1]
			let $qname :=
				if(contains($name,":")) then
					$name
				else
					$ns || ":" || $name
			let $qname := $qname || "#" || $arity
			return
				if(map:contains($params("dict"),$qname)) then
					map:get($params("dict"),$qname)
				else
					map {
						"name" := $name,
						"qname" := $qname,
						"ns" := $ns,
						"type" := $type,
						"args" := $args,
						"body" := if($l=3) then () else $value("args")(4)
					}
	return $def
};