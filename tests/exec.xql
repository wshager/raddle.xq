xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat-b.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace env="http://raddle.org/env" at "/db/apps/raddle.xq/lib/env.xql";
(:import module namespace console="http://exist-db.org/xquery/console";:)


declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};

declare function local:process-strings($strings,$ret,$index) {
    fold-left(1 to count($strings),$ret,function($ret,$index){
        let $head := $strings[$index]
        return
            if(name($head) eq "match") then
                let $string := $head/string()
                let $key := concat("%", $index,"%")
                return concat($ret,$key)
            else
                concat($ret,$head/string())
        
    })
(:    if(count($strings) eq 0) then:)
(:        $ret:)
(:    else:)
(:        let $head := head($strings):)
(:        return:)
(:            if(name($head) eq "match") then:)
(:                let $string := $head/string():)
(:                let $key := concat("$%", $index):)
(:                return local:process-strings(tail($strings),concat($ret,$key),$index + 1):)
(:            else:)
(:                local:process-strings(tail($strings),concat($ret,$head/strfing()),$index + 1):)
};

declare function local:normalize($query,$params) {
    let $strings := analyze-string($query,concat("('[^']*')|(",$env:QUOT,"[^",$env:QUOT,"]*",$env:QUOT,")"))/*
	return local:parse-strings(
		local:process-strings($strings, "" , 1),
		$strings,
		$params
	)
};

declare function local:restore-string($t,$v,$strings){
    if($t eq 7 and matches($v,"^%.*%$")) then
        $strings[position() eq xs:integer(replace($v,"%",""))]/string()
    else
        $v
};

declare function local:to-l3($pre,$entry,$strings,$at,$normalform,$size){
    let $t := $entry("t")
    let $v := local:restore-string($t,$entry("v"),$strings)
    let $v := if($t eq 7) then replace($v,"&quot;","") else $v
    let $s :=
        if($t = 1) then
            if($v eq "{") then
                15
            else if($v eq "(") then
                (: TODO check for last operator :)
                let $last := if($at gt 1) then $normalform($at - 1) else ()
                return if(exists($last) and $last("t") = (4,6,10)) then () else if(exists($last) and $last("t") eq 2) then () else (14,"")
            else
                ()
        else if($t eq 2) then
            let $next := if($at lt $size) then $normalform($at + 1) else ()
            return if(exists($next) and $next("t") eq 1) then 18 else 17
        else if($t eq 7) then
            (3,$v)
        else if($t eq 8) then
            (12,$v)
        else if($t = (4,6,10)) then
            (14,$v)
        else if($t eq 5) then
            (3,$v)
        else
            ()
    return ($pre,$s)
};

declare function local:parse-strings($processed, $strings, $params) {
    (: TODO write wrapper function that adds strings to map uniquely, only incrementing per string (double entry) :)
    let $normalform := xqc:normalize-query-b($processed,$params)
    let $output := $params("$transpile")
    return
        if($output eq "source") then
            a:fold-left($normalform,[],function($pre,$entry){
                let $t := $entry("t")
                let $v := local:restore-string($t,$entry("v"),$strings)
                return array:append($pre,xqc:tpl($t,$entry("d"),$v))
            })
        else if($output eq "l3") then
            a:fold-left-at($normalform,(),function($pre,$entry,$at){
                local:to-l3($pre,$entry,$strings,$at,$normalform,array:size($normalform))
            })
        else
            a:fold-left($normalform,"",function($pre,$entry){
                let $t := $entry("t")
                let $v := local:restore-string($t,$entry("v"),$strings)
                return concat($pre,$v)
            })
};

(: 
open comment=1
open quot = 2
open xml = 3
close comment=4
close quot = 5
close xml = 6
 :)
declare function local:analyze-char($char,$next,$type) {
    switch($char)
        case "(" return if($type eq 0 and $next eq ":") then 1 else $type
        case "&quot;" return if($type eq 2) then 5 else 2
        case "<" return if($type eq 0) then 3 else $type
        case "{" return if($type eq 3) then 6 else $type
        case ":" return if($type eq 1 and $next eq ")") then 4 else $type
        default return $type
};

declare function local:analyze-chars($chars) {
    local:analyze-chars((),tail($chars),head($chars),0,(),false(),false(),false())
};

declare function local:analyze-chars($ret,$chars,$char,$old-type,$buffer,$comment,$string,$xml) {
    (: if the type changes, flush the buffer :)
    let $type := local:analyze-char($char,head($chars),$old-type)
    return if(empty($chars)) then
        ($ret,concat($buffer,$char))
    else
        local:analyze-chars(($ret,if($type eq $old-type) then () else ($buffer,$type)),tail($chars),head($chars),if($type = (4,5,6)) then 0 else $type,if($type eq $old-type) then concat($buffer,$char) else $char,$type eq 1,$type eq 2,$type eq 3)
};

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat": "xquery", "$transpile": "l3"}
let $params :=
        if($params("$compat") eq "xquery") then
            map:put(map:put($params,"$operators",$xqc:operators),"$operator-map",$xqc:operator-map)
        else
            $params
let $file := "xq-compat-b"
let $dir := "lib"
let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/" || $dir || "/" || $file || ".xql"), "utf-8")

(:let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/" || $file || ".rdl"), "utf-8"):)
(:let $temp := xqc:dawg-find($xqc:operator-dawg,"d","d",$xqc:operator-map,false(),()):)
(:let $temp := xqc:dawg-find($temp(2),"e","de",$xqc:operator-map,false(),$temp(1)):)
(:return xqc:dawg-find($temp(2),"c","dec",$xqc:operator-map,false(),$temp(1)):)
(:let $rdl := json-doc("/db/apps/raddle.xq/ast/" || $file || ".json"):)
(:let $c := array { local:normalize($query,$params) }:)
(:return local:serialize($c):)
let $query := 'let $x := <test>{ "test" (: ok :) }</test>'
return local:analyze-chars(string-to-codepoints($query) ! codepoints-to-string(.))
(:return xmldb:store("/db/apps/raddle.xq/tests","l3.json",local:serialize($c),"application/json"):)

(:return xmldb:store("/db/apps/raddle.xq","operator-trie.json",local:serialize($xqc:operator-trie),"application/json"):)

(:let $rdl := rdl:parse($query,$params):)

(:return xmldb:store("/db/apps/raddle.xq/ast",$file || ".json",local:serialize($rdl),"application/json"):)
(:return xmldb:store("/db/apps/raddle.xq/js",$file || ".js",js:transpile($rdl, $params),"text/javascript"):)
(:return xmldb:store("/db/apps/raddle.xq/raddled", $file || ".rdl",rdl:stringify($rdl,$params),"text/plain"):)

(:return local:serialize($rdl):)
(:return rdl:stringify($rdl,$params):)
(:return js:transpile($rdl,$params):)
(:return xmldb:store("/db/data/test","test.js",js:transpile($rdl, $params),"text/javascript"):)
(:let $module := rdl:exec($query,$params):)
(:let $fn := $module("$exports")("test:add#2"):)
(:return $fn([2,3]):)
