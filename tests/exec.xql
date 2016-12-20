xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace rdl="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";


declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};

declare function local:normalize($query,$params) {
	let $strings := analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*
	return xqc:normalize-query(string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	})),$params)
};

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat": "xquery", "$transpile": "js"}

let $file := "xq-compat"
let $dir := "lib"
let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/" || $dir || "/" || $file || ".xql"), "utf-8")
(:let $query := 'declare function local:test(){:)
(:$no eq 26 or ($no eq 2.10 and $lastseen[last() - 1] eq 21.07):)
(:};':)
(:let $rdl := json-doc("/db/apps/raddle.xq/ast/" || $file || ".json"):)
(:return local:normalize($query,$params):)
(:return local:serialize(rdl:parse($query,$params)):)

let $rdl := rdl:parse($query,$params)

(:return xmldb:store("/db/apps/raddle.xq/ast",$file || ".json",local:serialize($rdl),"application/json"):)
return xmldb:store("/db/apps/raddle.xq/js",$file || ".js",rdl:transpile($rdl, "js", $params),"text/javascript")
(:return xmldb:store("/db/apps/raddle.xq/raddled","xq-compat.rdl",rdl:stringify($rdl,$params),"text/plain"):)

(:return local:serialize($rdl):)
(:return rdl:stringify($rdl,$params):)
(:return rdl:transpile($rdl,"js",$params):)
(:return xmldb:store("/db/data/test","test.js",rdl:transpile($rdl, "js", $params),"text/javascript"):)
(:let $module := rdl:exec($query,$params):)
(:let $fn := $module("$exports")("test:add#2"):)
(:return $fn([2,3]):)
