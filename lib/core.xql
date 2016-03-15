xquery version "3.1";

module namespace core="http://raddle.org/core";

import module namespace raddle="http://lagua.nl/lib/raddle" at "/db/apps/raddle.xq/content/raddle.xql";
import module namespace op="http://www.w3.org/2005/xpath-functions/op" at "/db/apps/raddle.xq/lib/op.xql";
import module namespace n="http://raddle.org/n" at "/db/apps/raddle.xq/lib/n.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare function core:elem($name,$content){
	n:element($name,$content)
};

declare function core:attr($name,$content){
	n:attribute($name,$content)
};

declare function core:cat($a1,$a2){
	concat($a1,$a2)
};


declare function core:cat($a1,$a2,$a3){
	concat($a1,$a2,$a3)
};

declare function core:bind($fn,$tuple,$type) {
	function($vals) {
		$fn($tuple($vals))
	}
};

declare function core:tuple($params,$context) {
	let $nu := console:log($params) return
	function($vals) {
		(: TODO create fold-left-at :)
		map:new((for $i in 1 to array:size($params)
			return
			$params($i)($vals($i),$context)))
	}
};

declare function core:map-put($map,$k,$v){
	map:new(($map,map:entry($k,$v)))
};

declare function core:function($name,$args,$type,$body,$params,$context) {
	core:map-put($context,$name,core:bind($body,core:tuple($args,map{}),$type))
};

declare function core:typegen($type,$name,$body) {
	let $cp := string-to-codepoints($name)
	let $suffix := if($cp[last()] = (42,43,45,63)) then
		codepoints-to-string($cp[last()])
		else
				""
	let $name := if($suffix eq "") then
		$name
	else
		codepoints-to-string(reverse(tail(reverse($cp))))
	return
		if($body instance of function() as item()) then
			function($val,$context) {
				$body(core:map-put($context,$name,$val))
			}
		else if($body) then
			(: default param value generator:)
			function($null,$context) {
				(: _check($body,$type);:)
				core:map-put($context,$name,$body)
			}
		else
			function($val,$context) {
				(: _check($val,$type);:)
				core:map-put($context,$name,$val)
			}
};

declare function core:typecheck($val,$type){
	if(util:eval("$val instance of " || $type)) then
		console:log(($val,$type))
	else
		console:log("Not of correct type")
};

declare function core:typegen($type,$name) {
	let $cp := string-to-codepoints($name)
	let $suffix := if($cp[last()] = (42,43,45,63)) then
		codepoints-to-string($cp[last()])
		else
				""
	let $name := if($suffix eq "") then
		$name
	else
		codepoints-to-string(reverse(tail(reverse($cp))))
	return
		function($val,$context) {
			let $n := core:typecheck($val,$type)
			return core:map-put($context,$name,$val)
		}
};

declare function core:integer() {
	"xs:integer"
};

declare function core:integer($name) {
	core:typegen("xs:integer",$name)
};

declare function core:integer($name,$val) {
	core:typegen("xs:integer",$name,$val)
};

declare function core:integer($name,$val,$context) {
	core:typegen("xs:integer",$name)($val,$context)
};

declare function core:integer($name,$val,$body,$context) {
	core:typegen("xs:integer",$name,$body)($val,$context)
};

declare function core:string() {
	"xs:string"
};

declare function core:string($name) {
	core:typegen("xs:string",$name)
};

declare function core:string($name,$val) {
	core:typegen("xs:string",$name,$val)
};

declare function core:string($name,$val,$context) {
	core:typegen("xs:string",$name)($val,$context)
};

declare function core:integer($name,$val,$body,$context) {
	core:typegen("xs:string",$name,$body)($val,$context)
};

declare function core:seq($val,$params,$context) {
	array:flatten($val)
};

declare function core:add($a,$b) {
	$a + $b
};

declare function core:export($args,$params,$context){
	let $args :=
		if($args instance of array(item()?)) then
			$args
		else
			[$args]
	return array:fold-left($args,map {},function($pre,$value){
		raddle:exec($value,$params,$context)
	})
};

declare function core:module($prefix,$ns,$desc,$args,$params,$context){
	map:new(($context, map:entry($prefix,core:export($args,$params,$context))))
};
