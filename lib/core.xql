xquery version "3.1";

module namespace core="http://raddle.org/core";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace op="http://www.w3.org/2005/xpath-functions/op" at "op.xql";
import module namespace n="http://raddle.org/native-xq" at "n.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare function core:elem($frame,$name,$content){
	n:element($name,$content)
};

declare function core:attr($frame,$name,$content){
	n:attribute($name,$content)
};

declare function core:text($frame,$content){
	n:text($content)
};

declare function core:define($frame,$name,$desc,$args,$type,$body) {
	(: print a nice picture for the params album... :)
	let $map := a:fold-left-at($args,map{},function($pre,$_,$i){
		$_($frame)($pre,(),$i)
	})
(:	let $n := console:log($map):)
	return
	map:new(($frame,
		map:entry("$functions",core:describe($frame("$functions"),$name,$desc,$args,$type)),
		map:entry("$exports",map:put($frame("$exports"),concat($name,"#",array:size($args)),n:bind($body,$args,$type)($frame)))
	))
};

declare function core:describe($frame,$name,$desc,$args,$type){
	map:put($frame,concat($name,"#",array:size($args)),
		map {
			"name": $name,
			"description": $desc
		}
	)
};

declare function core:function($args,$type,$body) {
	(: body+args are quotations :)
	n:bind($body,$args,$type)
};

declare function core:typecheck($type,$val){
	if(util:eval(concat("$val instance of ",$type))) then
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

declare function core:typegen($frame,$type,$name,$val) {
(:	function($frame) {:)
		(: _check($val,$type);:)
		map:put($frame,$name,$val)
(:	}:)
};

declare function core:typegen($frame,$type,$name) {
	function($frame,$val,$i) {
		(: add type to map just for posterity :)
		let $val := if(empty($val)) then $type else $val
		return map:put($frame,if($name eq "") then string($i) else $name,$val)
	}
};

declare function core:item() {
	(: TODO check a return type :)
	"item()"
};

declare function core:item($frame,$name) {
	core:typegen($frame,"item()",$name)
};

declare function core:item($frame,$name,$val) {
	core:typegen($frame,"item()",$name,$val)
};

declare function core:integer() {
	(: TODO check a return type :)
	"xs:integer"
};

declare function core:integer($frame,$name) {
	core:typegen($frame,"xs:integer",$name)
};

declare function core:integer($frame,$name,$val) {
	core:typegen($frame,"xs:integer",$name,$val)
};

declare function core:string() {
	"xs:string"
};

declare function core:string($frame,$name) {
	core:typegen($frame,"xs:string",$name)
};

declare function core:string($frame,$name,$val) {
	core:typegen($frame,"xs:string",$name,$val)
};

declare function core:apply($frame,$name,$args){
	let $self := core:is-current-module($frame,$name)
	let $f := core:resolve-function($frame, $name, $self)
	let $frame := map:put($frame,"$callstack",array:append($frame("$callstack"),$name))
(:	let $n := console:log($frame("$callstack")):)
	let $frame := map:put($frame,"$caller",$name)
	return
		if($self) then
			$f(core:process-args($frame,$args))
		else
			apply($f,core:process-args($frame,$args))
};

declare %private function core:is-current-module($frame,$name){
	map:contains($frame,"$prefix") and matches($name,concat("^",$frame("$prefix"),":"))
};

declare function core:resolve-function($frame,$name){
	core:resolve-function($frame,$name,core:is-current-module($frame,$name))
};

declare function core:resolve-function($frame,$name,$self){
	(: TODO move to bindings :)
	if($self) then
		$frame("$exports")($name)
	else
		let $parts := tokenize($name,":")
		let $prefix := if($parts[2]) then $parts[1] else ""
		let $module := $frame("$imports")($prefix)
		let $theirname := concat(if($module("$prefix")) then concat($module("$prefix"),":") else "", $parts[last()])
		return $module("$exports")($theirname)
};

declare function core:process-args($frame,$args){
	a:for-each-at($args,function($arg,$at){
		if($arg instance of array(item()?)) then
			(: check: composition or sequence? :)
			let $is-params := ($frame("$caller") eq "core:define#6" and $at = 4) or ($frame("$caller") eq "core:function#3" and $at = 1)
			let $is-body := $frame("$caller") eq "core:define#6" and $at = 6
			return
				if($is-params or (core:is-fn-seq($arg) = false() and $is-body = false())) then
					a:for-each($arg,function($_){
						(: FIXME properly convert params :)
						n:eval(if($_ instance of xs:string and matches($_,"^\$")) then map { "name":"core:item", "args": ["$",replace($_,"^\$","")] } else $_)
					})
				else
					n:eval($arg)
		else if($arg instance of map(xs:string,item()?)) then
			n:eval($arg)
		else if($arg eq ".") then
			$frame("0")
		else if($arg eq "$") then
			$frame
		else if(matches($arg,concat("^\$[",$raddle:ncname,"]+$"))) then
			(: retrieve bound value :)
			$frame(replace($arg,"^\$",""))
		else if(matches($arg,concat("^[",$raddle:ncname,"]?:?[",$raddle:ncname,"]+#(\p{N}|N)+"))) then
			core:resolve-function($frame,$arg)
		else
			$arg
	})
};


declare %private function core:is-fn-seq($value) {
	if(array:size($value) eq 0) then
		()
	else
		distinct-values(array:flatten(
			array:for-each($value,function($_){
				if($_ instance of map(xs:string, item()?)) then
					(: only check strings in sequence :)
					core:is-fn-seq($_("args"))
				else
					$_ instance of xs:string and matches($_,"^\.$|^\$$")
			})
		)) = true()
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
	(: BUT imports should be reused, so they are inserted into a global context... (and so may be mutable) :)
	map:new(($frame, map {
		"$prefix": $prefix,
		"$uri": $ns,
		"$description": $desc,
		"$functions": map {},
		"$exports": map {}
	}))
};
