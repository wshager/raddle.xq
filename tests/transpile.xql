xquery version "3.1";

import module namespace raddle="http://lagua.nl/lib/raddle" at "../content/raddle.xql";

declare function local:assert($rad,$test,$val) {
	let $value := raddle:parse($rad)
	let $params := map { "raddled" := "/db/apps/raddle.xq/raddled", "dict" := map {} }
	let $dict := raddle:process($value,$params)
	let $func := raddle:eval($dict,$params)
	let $ret := $func($test)
	return
		if(deep-equal($ret,$val)) then
			"Test successful: " || string-join($test,",") || " yielded " || $ret
		else
			"Test failed: " || string-join($test,",") || " yielded " || $ret
};

for-each((
	["use(fn/aggregate-functions,fn/string-regex-functions),define(depth,(string),number,(tokenize($1,/),count(.))),local:depth(.)",
		"/a/b/c",4],
	["use(op/numeric-arithmetic-operators),define(add2,(integer,integer,integer),number,(op:add($1,$2),op:add(.,$3))),local:add2(.,2,3)",
		1,6],
	["use(op/numeric-arithmetic-operators,fn/higher-order-functions),define(sum,(any*),number,fold-left($1,0,op:add#2)),local:sum(.)",
	    (1,2,3),6],
	["use(op/numeric-arithmetic-operators,op/numeric-comparison-operators,hof/unfold-functions,new/constructors),hof:unfold(.,(op:add(.,1)),(op:greater-than(.,10)),())",
	    1,[1,2,3,4,5,6,7,8,9,10]]
),function($_){
	apply(local:assert#3,$_)
})