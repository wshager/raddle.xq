xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat-b.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace env="http://raddle.org/env" at "/db/apps/raddle.xq/lib/env.xql";
import module namespace console="http://exist-db.org/xquery/console";


declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};

declare function local:process-strings($strings,$ret,$index) {
    let $Nu := console:log($strings) return
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
        replace($strings[position() eq xs:integer(replace($v,"%",""))]/string(),"&quot;","")
    else
        $v
};

declare function local:to-l3($pre,$entry,$strings){
    let $t := $entry("t")
    let $v := local:restore-string($t,$entry("v"),$strings)
    let $s :=
        if($t = 1) then
            if($v eq "{") then
                15
            else
                ()
        else if($t eq 2) then
            17
        else if($t = (6,7,8)) then
            (3,$v)
        else if($t = (4,10)) then
            (14,$v)
        else if($t eq 5) then
            (14,"$",3,$v,17)
        else
            ()
    return ($pre,$s)
};

declare function local:parse-strings($processed, $strings, $params) {
    (: TODO write wrapper function that adds strings to map uniquely, only incrementing per string (double entry) :)
    let $process := if($params("l3")) then
        function($pre,$entry){
            local:to-l3($pre,$entry,$strings)
        }
    else
        function($pre,$entry){
            let $t := $entry("t")
            let $v := local:restore-string($t,$entry("v"),$strings)
            return concat($pre,$v)
        }
	return a:fold-left(xqc:normalize-query-b($processed,$params),"",$process)
};

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat": "xquery", "$transpile": "js" , "l3": true()}
let $params :=
        if($params("$compat") eq "xquery") then
            map:put(map:put($params,"$operators",$xqc:operators),"$operator-map",$xqc:operator-map)
        else
            $params
let $file := "js"
let $dir := "lib"
(:let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/" || $dir || "/" || $file || ".xql"), "utf-8"):)
(:let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/" || $file || ".rdl"), "utf-8"):)
let $query := '
for $x in collection("/db") return $x + 1
'
(:let $temp := xqc:dawg-find($xqc:operator-dawg,"d","d",$xqc:operator-map,false(),()):)
(:let $temp := xqc:dawg-find($temp(2),"e","de",$xqc:operator-map,false(),$temp(1)):)
(:return xqc:dawg-find($temp(2),"c","dec",$xqc:operator-map,false(),$temp(1)):)
(:let $rdl := json-doc("/db/apps/raddle.xq/ast/" || $file || ".json"):)
let $c := local:normalize($query,$params)
return $c

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
