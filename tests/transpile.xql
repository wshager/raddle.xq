xquery version "3.1";

import module namespace raddle="http://lagua.nl/lib/raddle" at "lib/raddle.xql";

declare function local:assert($rad,$test,$val) {
	let $value := raddle:parse($rad)
	let $params := map { "raddled" := "/db/apps/raddle-tests/raddled", "dict" := map {} }
	let $dict := raddle:process($value,$params)
	let $func := raddle:eval($dict,$params)
	let $ret := $func($test)
	return
		if($ret = $val) then
			"Test successful: " || $test || " yielded " || $val
		else
			"Test failed: " || $test || " yielded " || $val
};

for-each((
	["use(core/aggregate-functions,core/string-regex-functions),define(depth,(string),number,(tokenize(.,/),count(.))),local:depth(.)",
		"/a/b/c",4],
	["use(op/numeric-arithmetic-operators),define(add2,(number,number,number),number,(op:add(.,?),op:add(.,?))),local:add2(.,2,3)",
		1,6]
),function($_){
	apply(local:assert#3,$_)
})