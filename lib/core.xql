xquery version "3.1";

module namespace core="http://raddle.org/core";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace op="http://www.w3.org/2005/xpath-functions/op" at "op.xql";
import module namespace n="http://raddle.org/native-xq" at "n.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare function core:elem($name,$content){
	n:element($name,$content)
};

declare function core:attr($name,$content){
	n:attribute($name,$content)
};

declare function core:text($content){
	n:text($content)
};

declare function core:define($frame,$name,$desc,$args,$type,$body) {
	(: TODO conform to eXist inspect:* argument properties :)
	core:function(
		map:put($frame,"$functions",map:put($frame("$functions"),$name || "#" || array:size($args),
			map {
				"name": $name,
				"description": $desc
			}
		)),$name,$args,$type,$body)
};

declare function core:function($frame,$name,$args,$type,$body) {
	map:put($frame,"$exports",map:put($frame("$exports"),$name || "#" || array:size($args),n:bind($body,$args,$frame,$type)))
};

declare function core:typecheck($type,$val){
	if(util:eval("$val instance of " || $type)) then
		console:log(($val,$type))
	else
		console:log("Not of correct type")
};

declare function core:get-name-suffix($name){
	let $cp := string-to-codepoints($name)
	return
		if($cp[last()] = (42,43,45,63,95)) then
			(codepoints-to-string(reverse(tail(reverse($cp)))),codepoints-to-string($cp[last()]))
		else
			($name,"")
};

declare function core:typegen($type,$name,$val) {
	let $parts := core:get-name-suffix($name)
	let $name := $parts[1]
	let $suffix := $parts[2]
	return
(:		if($body instance of function() as item()) then:)
(:			(: create closure over variable :):)
(:			function($val,$context) {:)
(:				$body(map:put($context,$name,$val)):)
(:			}:)
(:		else if($body) then:)
(:			(: default param value generator:):)
(:			function($null,$context) {:)
(:				(: _check($body,$type);:):)
(:				map:put($context,$name,$body):)
(:			}:)
(:		else:)
			function($frame) {
				(: _check($val,$type);:)
				map:put($frame,$name,$val)
			}
};

declare function core:typegen($type,$name) {
	let $parts := core:get-name-suffix($name)
	let $name := $parts[1]
	let $suffix := $parts[2]
	return
		function($val,$i,$frame) {
			map:put($frame,if($name eq "") then string($i) else $name,$val)
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

(:declare function core:integer($name,$val,$context) {:)
(:	core:typegen("xs:integer",$name)($val,$context):)
(:};:)
(::)
(:declare function core:integer($name,$val,$body,$context) {:)
(:	core:typegen("xs:integer",$name,$body)($val,$context):)
(:};:)

declare function core:string() {
	"xs:string"
};

declare function core:string($name) {
	core:typegen("xs:string",$name)
};

declare function core:string($name,$val) {
	core:typegen("xs:string",$name,$val)
};
(::)
(:declare function core:string($name,$val,$context) {:)
(:	core:typegen("xs:string",$name)($val,$context):)
(:};:)
(::)
(:declare function core:integer($name,$val,$body,$context) {:)
(:	core:typegen("xs:string",$name,$body)($val,$context):)
(:};:)

declare function core:resolve-function($frame,$name){
	(: TODO move to bindings :)
	if(map:contains($frame,"$prefix") and matches($name,"^" || $frame("$prefix") || ":")) then
		$frame("$exports")($name)
	else
		let $parts := tokenize($name,":")
		let $prefix := if($parts[2]) then $parts[1] else ""
		let $module := $frame("$imports")($prefix)
		let $theirname := concat(if($module("$prefix")) then $module("$prefix") || ":" else "", $parts[last()])
		return $module("$exports")($theirname)
};

declare function core:process-args($frame,$args){
	core:for-each($args,function($arg){
		if($arg instance of array(item()?)) then
			(: check: composition or sequence? :)
			let $fn-seq := core:is-fn-seq($arg)
			return
				if(empty($fn-seq)) then
					core:for-each($arg,function($_){
						n:eval($_)($frame)
					})
				else
					n:eval($arg)($frame)
		else if($arg instance of map(xs:string,item()?)) then
			n:eval($arg)
		else if($arg eq ".") then
			$frame("0")
		else if($arg eq "$") then
			$frame
		else if(matches($arg,"^\$[" || $raddle:ncname || "]+$")) then
			$frame(replace($arg,"^\$",""))
		else if(matches($arg,"^[" || $raddle:ncname || "]?:?[" || $raddle:ncname || "]+#(\p{N}|N)+")) then
			core:resolve-function($frame,$arg)
		else
			$arg
	})
};

declare function core:fold-left($array,$zero,$function){
	if(array:size($array) eq 0) then
		$zero
	else
		core:fold-left(array:tail($array), $function($zero, array:head($array)), $function )
};

declare function core:fold-left-at($array,$zero,$function) {
	core:fold-left-at($array,$zero,$function,1)
};

declare function core:fold-left-at($array,$zero,$function,$at){
	if(array:size($array) eq 0) then
		$zero
	else
		core:fold-left-at(array:tail($array), $function($zero, array:head($array), $at), $function, $at + 1)
};

declare function core:for-each($array,$function){
	core:for-each($array,$function,[])
};

declare function core:for-each($array,$function,$ret){
	if(array:size($array) eq 0) then
		$ret
	else
		core:for-each(array:tail($array), $function, array:append($ret,$function(array:head($array))))
};

declare function core:for-each-at($array,$function){
	core:for-each-at($array,$function,[],1)
};

declare function core:for-each-at($array,$function,$ret,$at){
	if(array:size($array) eq 0) then
		$ret
	else
		core:for-each-at(array:tail($array), $function, array:append($ret,$function(array:head($array), $at)), $at + 1)
};

declare function core:is-fn-seq($value) {
	if(array:size($value) eq 0) then
		()
	else
		distinct-values(array:flatten(
			array:for-each($value,function($_){
				if($_ instance of map(xs:string, item()?)) then
					(: only check strings in sequence :)
					core:is-fn-seq($_("args"))
				else if($_ instance of xs:string and matches($_,"^[\$\.]")) then
					$_
				else
					()
			})
		))
};

declare function core:import($frame,$prefix,$uri){
	core:import($frame,$prefix,$uri,())
};

declare function core:import($frame,$prefix,$uri,$location){
	(: check if we import a native module :)
	(: in a host environment, the global context would be modified :)
	(: and a pointer would be inserted to the module in the global context :)
	let $import :=
		if(empty($location) or xmldb:get-mime-type(xs:anyURI($location)) eq "application/xquery") then
			n:import($location)
		else
			let $src := util:binary-to-string(util:binary-doc($location))
			return n:eval(raddle:parse($src,$frame))($frame)
	return map:put($frame,"imports",map:put($frame("imports"),$prefix,$core))
};

declare function core:module($frame,$prefix,$ns,$desc){
	(: insert module into global context, overwrites this copy! :)
	(: any function in module is a function or var declaration ! :)
	(: TODO context for functions is a module, context for imports also (i.e. mappings) :)
	(: BUT imports should be reused, so they're inserted into a global context... (and so may be mutable) :)
	map:new(($frame, map {
		"$prefix": $prefix,
		"$uri": $ns,
		"$description": $desc,
		"$functions": map {},
		"$exports": map {}
	}))
};
