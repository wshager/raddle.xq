xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";


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


let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat" := "xquery"}

let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/lib/core.xql"), "utf-8")
(:let $query := 'core:module($,test,test,test),core:define($,test:add,(),(core:integer($,x),core:integer($,y)),core:integer(),(core:integer($,z,$y),n:add($x,$z)))':)

(:let $query := 'declare function core:define($frame,$name,$desc,$args,$type,$body) {:)
(:	a:fold-left-at($args,map{},function($pre,$_,$i){:)
(:		let $x := $frame return $_($x)($pre,(),$i):)
(:	}):)
(:};':)


(:return local:normalize($query,$params):)
(:return local:serialize(raddle:parse($query,$params)):)
(:return raddle:stringify(raddle:parse($query,$params),$params):)
return xmldb:store("/db/apps/raddle.xq/raddled","core.rdl",raddle:stringify(raddle:parse($query,$params),$params),"text/plain")

(:let $module := raddle:exec($query,$params):)
(:let $fn := $module("$exports")("test:add#2"):)
(:return $fn([2,3]):)
