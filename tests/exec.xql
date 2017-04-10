xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace rdl="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace js="http://raddle.org/javascript" at "../lib/js.xql";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";
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
(:                local:process-strings(tail($strings),concat($ret,$head/string()),$index + 1):)
};

declare function local:normalize($query,$params) {
	local:parse-strings(
		local:process-strings(analyze-string($query,concat("('[^']*')|(",$env:QUOT,"[^",$env:QUOT,"]*",$env:QUOT,")"))/*, "" , 1),
		$params
	)
};


declare function local:parse-strings($strings,$params) {
    (: TODO write wrapper function that adds strings to map uniquely, only incrementing per string (double entry) :)
	xqc:normalize-query-b($strings,$params)
};

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat": "xquery", "$transpile": "js"}
let $params :=
        if($params("$compat") eq "xquery") then
            map:put(map:put($params,"$operators",$xqc:operators),"$operator-map",$xqc:operator-map)
        else if($params("$compat") eq "rql") then
            map:put(map:put($params,"$operators",$rdl:operators),"$operator-map",$rdl:operator-map)
        else
            $params
let $file := "js"
let $dir := "lib"
let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/" || $dir || "/" || $file || ".xql"), "utf-8")
(:let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/" || $file || ".rdl"), "utf-8"):)
(:let $query := ':)
(:import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";:)
(::)
(:declare variable $local:m := map{"X":function(){}};:)
(::)
(:declare function local:test($x) {:)
(:    let $x := -$x return $x:)
(:};:)
(:':)
(:let $temp := xqc:dawg-find($xqc:operator-dawg,"d","d",$xqc:operator-map,false(),()):)
(:let $temp := xqc:dawg-find($temp(2),"e","de",$xqc:operator-map,false(),$temp(1)):)
(:return xqc:dawg-find($temp(2),"c","dec",$xqc:operator-map,false(),$temp(1)):)
(:let $rdl := json-doc("/db/apps/raddle.xq/ast/" || $file || ".json"):)
let $c := local:normalize($query,$params)
return $c

(:return local:serialize(rdl:parse($query,$params)):)

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
