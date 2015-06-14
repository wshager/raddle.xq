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


declare function raddle:parse($query as xs:string) {
    raddle:parse($query, ())
};

declare function raddle:parse($query as xs:string?, $parameters as xs:anyAtomicType?) {
    let $query:= raddle:normalize-query($query,$parameters)
    return if($query ne "") then
        let $analysis := analyze-string($query, $raddle:leftoverRegExp)
        let $analysis :=
            for $x in $analysis/* return
                    if(name($x) eq "non-match") then
                        replace(replace($x,",",""),"\(","<args>")
                    else
                        let $property := $x/fn:group[@nr=1]/text()
                        let $operator := $x/fn:group[@nr=2]/text()
                        let $value := $x/fn:group[@nr=4]/text()
                        let $closedParen := $x/fn:group[@nr=1]/text()
                        let $delim := $x/fn:group[@nr=2]/text()
                        let $propertyOrValue := $x/fn:group[@nr=3]/text()
                        let $openParen := $x/fn:group[@nr=4]/text()

                let $r := 
                    if($openParen) then
                        concat($propertyOrValue,"(")
                    else if($closedParen) then
                        ")"
                    else if($propertyOrValue or $delim eq ",") then
                        $propertyOrValue
                    else
                        ()
                return for $s in $r return
                    (: treat number separately, throws error on compare :)
                    if(string(number($s)) ne "NaN") then
                        concat("<args>",$s, "</args>")
                    else if(matches($s,"^.*\($")) then
                        concat("<args><name>",replace($s,"\(",""),"</name>")
                    else if($s eq ")") then 
                        "</args>"
                    else if($s eq ",") then 
                        "</args><args>"
                    else 
                        concat("<args>",$s, "</args>")
        let $q := string-join($analysis,"")
        return util:parse(string-join(concat("<root>",$q,"</root>"),""))
    else
        <args/>
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

declare function raddle:wrap($dict,$value,$i,$o,$a,$acc){
    let $v := array:head($value)
    let $arity := count($v("args"))
    let $aname := $v("name") || "#" || $arity
    let $def := map:get($dict,$aname)
    let $f := function-lookup($v("name"),$arity)
    (:if(!$def) {
        throw new Error("Definition for "+aname+" not in dictionary")
    }
    if(i and !self.matchTypes(i,def.sigs[0])){
        throw new Error("Type signatures do not match: "+i+"->"+def.sigs[0])
    }:)
    (: accumulator is a composed function :)
    let $acc := insert-before($acc,1,"(" || $def("body") || ")(")
    (: TODO static arg type checks
    let $err :=
        if($v("args")) then
            if(!$def("args") or count($v("args")) != size($def("args"))) then
                throw new Error("Argument length incorrect")
            else if(def.args) then
                throw new Error("No arguments supplied")
            else 
                ():)
    let $args := array:for-each($v("args"),function($_,$i){
        if($_ = "?") then
            head($a)
        else if($_ instance of array(item()?)) then
            (: compile to function :)
            let $f := raddle:compile($defs,$_,(),$a)
            return $f
        (:
        } else if(typeOf(_) == "query"){
            // compile and execute with args
            // TODO execute with provided args
            // if input is null and no args, exec with null
            let $f := self.compile(_,null,a,true)
            console.warn(f.toString())
            return f.toString()
        :)
        else
            let $t := $def("args")[$i]
            let $r := raddle:convert($_)
            let $r := 
                if($r instance of xs:string and matches($r,"^.+#[0-9]+$/")) then
                    map:get($dict,$r)("body")
                else
                    $r
            (: check type here :)
            (:if(!self.typeCheck(r,t)){
                throw new Error("Expected type ",t," for argument value ",r)
            }
            if(typeof r == "function"){
                return r.toString()
            } else {
                return JSON.stringify(r)
            }:)
            return $r
    })
    let $acc := insert-before($acc,(if(count($args)) then "," else "") || string-join($args,",")  || ")")
    return
        if(count($value) > 2) then
            raddle:wrap(tail($value),map:get($def,"sigs")[2],$o,$a,$acc)
        else
            (:if(o and !self.matchTypes(o,def.sigs[1])){
                throw new Error("Type signatures do not match: "+o+"->"+def.sigs[1])
            }:)
            $acc
};

declare function raddle:compile($dict,$value,$parent,$pa){
    (: if there are unknown args, take them from the definition :)
    let $arity := count($args)
    let $a :=
        for $i in 1 to $arity return "arg" || $i
    let $fa := subsequence($a,2)
    let $fa := insert-before($fa,1,"arg0")
    let $fargs := string-join($fa,",")
    (: compose the functions in the value array :)
    let $f := raddle:wrap($dict,$value,$sigs[1],$sigs[2],(if($parent) then $a else $pa),[])
    (: put default input arg in a :)
    let $a := insert-before($a,1,"arg0")
    let $f := insert-before($f,count($f)/2,string-join($a,","))
    return $f
};