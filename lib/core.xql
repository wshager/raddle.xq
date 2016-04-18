xquery version "3.1";

module namespace core="http://raddle.org/core";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace op="http://www.w3.org/2005/xpath-functions/op" at "op.xql";
import module namespace n="http://raddle.org/native-xq" at "n.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare function core:element($frame,$name,$content){
	n:element($name,$content)
};

declare function core:attribute($frame,$name,$content){
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

declare function core:get-name-suffix($name){
	let $cp := string-to-codepoints($name)
	return
		if($cp[last()] = (42,43,45,63,95)) then
			(codepoints-to-string(reverse(tail(reverse($cp)))),codepoints-to-string($cp[last()]))
		else
			($name,"")
};


declare function core:typegen1($type,$valtype) {
	util:eval(concat($type,"(",$valtype,")"))
};

declare function core:typegen1($type,$seq) {
	if($type eq "array") then
		n:array($seq)
	else
		()
};

declare function core:typegen2($type,$keytype,$valtype,$body) {
	if($type eq "map") then
		util:eval(concat("map {",$body,"}"))
	else
		core:function($keytype,$valtype,$body)
};

declare function core:typegen2($type,$keytype,$valtype) {
	util:eval(concat($type,"(",$valtype,")"))
};

declare function core:typegen2($type,$body) {
	if($type eq "map") then
		util:eval(concat("map {",$body,"}"))
	else
		()
};

declare function core:typegen2($type,$keytype,$valtype,$body) {
	if($type eq "map") then
		util:eval(concat("map {",$body,"}"))
	else
		core:function($keytype,$valtype,$body)
};

declare function core:typegen($type,$frame,$name,$val) {
(:	function($frame) {:)
		(: _check($val,$type);:)
		map:put($frame,$name,$val)
(:	}:)
};

declare function core:typegen($type,$frame,$name) {
	function($frame,$val,$i) {
		(: add type to map just for posterity :)
		let $val := if(empty($val)) then $type else $val
		return map:put($frame,if($name eq "") then string($i) else $name,$val)
	}
};


(:declare function core:op($op,$a) {:)
(:	core:op($op,"",$a):)
(:};:)

(:declare function core:op($op,$a,$b) {:)
(:	util:eval(concat($a," ",$n:operator-map($op)," ",$b)):)
(:};:)

declare function core:eval($value){
	(: if sequence, call n:seq, else call n:function :)
	(: pass the context through sequence with function calls :)
	(: global context consists of flags, functions, variables, prefix mapping, :)
	(: frame context is used to store params and local variables :)
	if($value instance of array(item()?)) then
		n:quote-seq($value)
	else if($value instance of map(xs:string,item()?)) then
		let $name := $value("name")
		let $args := $value("args")
		let $s := array:size($args)
		return
			if(matches($name,"^core:[" || $raddle:ncname || "]+$")) then
				let $local := replace($name,"^core:","")
				let $is-type := $local = map:keys($n:typemap)
				let $is-op := map:contains($n:operator-map,$local)
				let $args :=
					if($is-type or $is-op) then
						array:insert-before($args,1,$local)
					else
						$args
				let $name :=
					if($is-type) then
						(: call typegen/constructor :)
						let $a := $n:typemap($local)
						return concat("core:typegen",if($a > 0) then $a else "","#",$s + 1)
(:					else if($is-op) then:)
(:						(: call op :):)
(:						let $a := $n:operator-map($local):)
(:						return concat("core:op#",$s + 1):)
					else
						concat($name,"#",$s)
				return n:quote($name,$args)
			else
				let $name :=
					if($name eq "") then
						concat("n:seq#",$s)
					else
						concat($name,"#",$s)
				return n:quote($name,$args)
	else
(:		let $value := :)
(:			if(matches($value,"^_[" || $raddle:suffix || "]?$")) then:)
(:				replace($value,"^_","\$_" || $frame("$at")):)
(:			else:)
(:				$value:)
(:		return:)
		n:quote($value)
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
			(: eval nested calls !:)
			n:eval($arg)($frame)
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
