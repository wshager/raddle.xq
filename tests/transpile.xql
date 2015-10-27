xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

declare function local:assert($rad,$test,$val,$params) {
	let $xq := raddle:transpile($rad,$params)
	let $func := util:eval($xq)
	let $ret := $func($test)
	return
		(if(deep-equal($ret,$val)) then
			"Test successful: "
		else
			"Test failed: ") || local:serialize($test) || " yielded " || local:serialize($ret)
};

declare function local:serialize($dict){
    serialize($dict,
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)
};

let $params := map { "raddled" := "/db/apps/raddle.xq/raddled", "dict" := map {}}

return for-each((
	["use(fn/aggregate-functions,fn/string-regex-functions),define(depth,(string),number,(tokenize($1,/),count(.))),local:depth(.)",
	    "a/b/c",3],
	["use(op/numeric-arithmetic-operators),define(add2,(integer,integer,integer),number,(op:add($1,$2),op:add(.,$3))),local:add2(.,2,3)",
		1,6],
	["use(op/numeric-arithmetic-operators,fn/higher-order-functions),define(sum,(any*),number,fold-left($1,0,op:add#2)),local:sum(.)",
	    (1,2,3),6],
	["use(op/numeric-arithmetic-operators,op/numeric-comparison-operators,hof/unfold-functions),hof:unfold(.,(op:add(.,1)),(op:greater-than(.,10)),())",
	    1,[1,2,3,4,5,6,7,8,9,10]]
),function($_){
    if($_ instance of array(item()?)) then
	    apply(local:assert#4,array:append($_,$params))
	else
	    raddle:transpile($_,$params)
})