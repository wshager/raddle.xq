xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

declare function local:module($rad,$def) {
	let $value := raddle:parse($rad)
	let $params := map { "raddled" := "/db/apps/raddle.xq/raddled", "dict" := map {}, "module" := $def }
	let $dict := raddle:process($value,$params)
	let $store := raddle:store-module($dict,$params)
	return "Module successfully stored: " || $store
};

declare function local:assert($rad,$test,$val) {
	let $value := raddle:parse($rad)
	let $params := map { "raddled" := "/db/apps/raddle.xq/raddled", "dict" := map {}}
	let $dict := raddle:process($value,$params)
	let $func := raddle:eval($dict,$params)
	let $ret := $func($test)
	return
		if(deep-equal($ret,$val)) then
			"Test successful: " || local:serialize($test) || " yielded " || local:serialize($ret)
		else
			"Test failed: " || local:serialize($test) || " yielded " || local:serialize($ret)

};

declare function local:serialize($dict){
    serialize($dict,
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)
};

for-each((
	["use(fn/aggregate-functions,fn/string-regex-functions),define(depth:depth,(string),number,(tokenize($1,/),count(.)))",map {"location" := "/db/apps/raddle.xq/tests/src/depth.xql", "prefix" := "depth", "uri" := "http://lagua.nl/lib/depth"}],
	["use(op/numeric-arithmetic-operators),define(add2,(integer,integer,integer),number,(op:add($1,$2),op:add(.,$3))),local:add2(.,2,3)",
		1,6],
	["use(op/numeric-arithmetic-operators,fn/higher-order-functions),define(sum,(any*),number,fold-left($1,0,op:add#2)),local:sum(.)",
	    (1,2,3),6],
	["use(op/numeric-arithmetic-operators,op/numeric-comparison-operators,hof/unfold-functions),hof:unfold(.,(op:add(.,1)),(op:greater-than(.,10)),())",
	    1,[1,2,3,4,5,6,7,8,9,10]]
),function($_){
    if(array:size($_) = 3) then
    	apply(local:assert#3,$_)
    else
        apply(local:module#2,$_)
})