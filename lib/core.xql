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
	function($vals) {
		(: TODO create fold-left-at :)
		map:new((for $i in 1 to array:size($params)
			return
			$params($i)($vals($i),$context)))
	}
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
	let $x := console:log($args)
	let $args := array:for-each($args,function($_){
		let $n := console:log(inspect:inspect-function($_)) return $_($frame) })
	let $binding := core:bind($body,core:tuple($args,map{}),$type)
	return map:put($frame,"$exports",map:put($frame("$exports"),$name || "#" || array:size($args),$binding))
};

declare function core:typecheck($val,$type){
	if(util:eval("$val instance of " || $type)) then
		console:log(($val,$type))
	else
		console:log("Not of correct type")
};

declare function core:typegen($type,$name,$body) {
	let $cp := string-to-codepoints($name)
	let $suffix :=
		if($cp[last()] = (42,43,45,63)) then
			codepoints-to-string($cp[last()])
		else
			""
	let $name := if($suffix eq "") then
		$name
	else
		codepoints-to-string(reverse(tail(reverse($cp))))
	let $nu := console:log(($type,$name))
	return
		if($body instance of function() as item()) then
			function($val,$context) {
				$body(map:put($context,$name,$val))
			}
		else if($body) then
			(: default param value generator:)
			function($null,$context) {
				(: _check($body,$type);:)
				map:put($context,$name,$body)
			}
		else
			function($val,$context) {
				(: _check($val,$type);:)
				map:put($context,$name,$val)
			}
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
			return map:put($context,$name,$val)
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

declare function core:seq($value,$context) {
	array:fold-left($value,$context,function($pre,$cur){
		map:new(($pre,core:exec($cur,$pre)))
	})
};

declare function core:add($a,$b) {
	$a + $b
};

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

declare function core:exec($value,$frame){
	core:exec($value,$frame,false())
};

declare function core:exec($value,$frame,$top){
	(: if sequence, call core:seq, else call core:function :)
	(: pass the context through sequence with function calls :)
	(: global context consists of flags, functions, variables, prefix mapping, :)
	(: frame context is used to store params and local variables :)
	if($value instance of array(item()?)) then
		array:fold-left($value,$frame,function($pre,$cur){
			map:new(($pre,core:exec($cur,$pre,$top)))
		})
	else if($value instance of map(xs:string,item()?)) then
		let $args := $value("args")
		let $name :=
			if($value("name") eq "") then
				"seq#" || array:size($args)
			else
				$value("name") || "#" || array:size($args)
		(: TODO process args :)
		(: args may contain values, variables, dots or function references :)
		(: a dot contains the (query) context, i.e. the return value of the previous function, and is stored in index 0 (zero) of the stack context :)
		(: if exec is called from raddle (i.e. TOP) there's frame context, but the global context is passed instead :)
		(: else a wrapper function is returned, that applies the frame context to the function as its arguments :)
		(: the function should receive a reference to the real function by way of closure :)
		(: TODO the frame is an array, variable and parameter names are dereferenced first (i.e. referenced by their order) :)
		(: the frame is a mutable (map) and is passed down the entire program. it relies on the purity of functions for immutability :)
		let $function := function($frame){
			let $nu := console:log(inspect:inspect-function(core:resolve-function($frame,$name))) return
			apply(core:resolve-function($frame,$name),array:for-each($args,function($arg){
				let $nu := console:log($arg) return
				if($arg instance of array(item()?)) then
					core:exec($arg,$frame,true())
				else if($arg instance of map(xs:string,item()?)) then
					core:exec($arg,$frame)
				else if($arg eq ".") then
					$frame("0")
				else if($arg eq "$") then
					$frame
		(:		else if($arg eq "$$") then:)
		(:			$context:)
				else if(matches($arg,"^\$[" || $raddle:ncname || "]+$")) then
					$frame(replace($arg,"^\$",""))
				else if(matches($arg,"^[" || $raddle:ncname || "]?:?[" || $raddle:ncname || "]+#(\p{N}|N)+")) then
					(: where does it reside? in imports or in exports? :)
					core:resolve-function($frame,$arg)
				else
					$arg
			}))
		}
		return
			if($top) then
				$function($frame)
			else
				$function
	else
		raddle:serialize($value,map{})
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
			let $module := inspect:inspect-module(xs:anyURI($location))
			let $fns-desc := $module/function
			let $fns := inspect:module-functions(xs:anyURI($location))
			return
				map {
					"$uri":$module/@uri,
					"$prefix":$module/@prefix,
					"$location":$module/@location,
					"$exports":
						map:new(
							for $fn-desc at $i in $fns-desc return
								map:entry($fn-desc/@name || "#" || count($fn-desc/argument),$fns[$i])
						)
				}
		else
			let $src := util:binary-to-string(util:binary-doc($location))
			return core:exec(raddle:parse($src,$frame),$frame,true())
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
