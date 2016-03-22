xquery version "3.1";

module namespace n="http://raddle.org/native-xq";
import module namespace core="http://raddle.org/core" at "core.xql";
import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare function n:import($location){
		let $module := inspect:inspect-module(xs:anyURI($location))
	let $fns := inspect:module-functions(xs:anyURI($location))
	return
		map {
			"$uri":$module/@uri,
			"$prefix":$module/@prefix,
			"$location":$module/@location,
			"$functions":
				[for-each($module/function,function($fn-desc) {
					map {
						"name":$fn-desc/@name,
						"arguments":[
							for-each($fn-desc/argument,function($arg){
								map {
									"var": $arg/@var,
									"type": $arg/@type,
									"cardinality":
										switch($arg/@cardinality)
											case "zero or more" return "*"
											case "zero or one" return "?"
											default return ""
								}
							})
						]
					}
				})],
			"$exports":
				map:new(
					for $fn-desc at $i in $module/function return
						map:entry($fn-desc/@name || "#" || count($fn-desc/argument),$fns[$i])
				)
		}
};


declare function n:fold-left-at($array,$zero,$function) {
	n:fold-left-at($array,$zero,$function,1)
};

declare function n:fold-left-at($array,$zero,$function,$at){
	if(array:size($array) eq 0) then
		$zero
	else
		n:fold-left-at(array:tail($array), $function($zero, array:head($array), $at), $function, $at + 1)
};

declare function n:bind($fn,$args,$frame,$type) {
		(: FIXME frame is bound early, fold-left-at import is broken :)
		let $tuple := function($vals) {
		n:fold-left-at($args,$frame,function($pre,$cur,$i){
				$cur($vals($i),$i,$pre)
		})
	}
	return function($vals) {
		$fn($tuple($vals))
	}
};

declare function n:eval($value){
	(: if sequence, call n:seq, else call n:function :)
	(: pass the context through sequence with function calls :)
	(: global context consists of flags, functions, variables, prefix mapping, :)
	(: frame context is used to store params and local variables :)
	if($value instance of array(item()?)) then
		let $function := function($frame) {
			core:fold-left($value,$frame,function($pre,$cur){
					let $n := console:log($cur) return
				n:eval($cur)($pre)
			})
		}
		return $function
	else if($value instance of map(xs:string,item()?)) then
		let $args := $value("args")
		let $name :=
			if($value("name") eq "") then
				"n:seq#" || array:size($args)
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
		return function($frame){
			apply(core:resolve-function($frame,$name),core:process-args($frame,$args))
		}
	else
(:		let $value := :)
(:			if(matches($value,"^_[" || $raddle:suffix || "]?$")) then:)
(:				replace($value,"^_","\$_" || $frame("$at")):)
(:			else:)
(:				$value:)
(:		return:)
		function($frame){
			$value
		}
};

declare function n:if($test,$true,$false) {
		if($test) then
				$true
		else
				$false
};

declare function n:eq($a,$b) {
		$a eq $b
};

declare function n:select($a,$b) {
		util:eval("$a/" || $b)
};

declare function n:add($a as xs:integer,$b as xs:integer) {
	$a + $b
};

declare function n:subtract($a,$b) {
	$a - $b
};

declare function n:map() {
		map {}
};

declare function n:array() {
		[]
};

declare function n:element($name,$content) {
		element {$name} {
				$content
		}
};

declare function n:attribute($name,$content) {
		attribute {$name} {
				$content
		}
};

declare function n:text($content) {
		text {
				$content
		}
};

declare function n:seq($value,$context) {
	core:fold-left($value,$context,function($pre,$cur){
		n:eval($cur)($pre)
	})
};

(: alas :)
declare function n:concat($a,$b){
	concat($a,$b)
};

declare function n:concat($a,$b,$c){
	concat($a,$b,$c)
};

declare function n:concat($a,$b,$c,$d){
	concat($a,$b,$c,$d)
};

declare function n:concat($a,$b,$c,$d,$e){
	concat($a,$b,$c,$d,$e)
};

declare function n:concat($a,$b,$c,$d,$e,$f){
	concat($a,$b,$c,$d,$e,$f)
};

declare function n:concat($a,$b,$c,$d,$e,$f,$g){
	concat($a,$b,$c,$d,$e,$f,$g)
};

declare function n:concat($a,$b,$c,$d,$e,$f,$g,$h){
	concat($a,$b,$c,$d,$e,$f,$g,$h)
};
