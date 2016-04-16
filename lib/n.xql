xquery version "3.1";

module namespace n="http://raddle.org/native-xq";
import module namespace core="http://raddle.org/core" at "core.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";
import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";

declare variable $n:typemap := map {
	"integer": 0,
	"string": 0,
	"item": 0,
	"anyURI": 0,
	"map": 2,
	"function": 2,
	"array": 1
};

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

declare function n:eval($value) {
	core:eval($value)
};

declare function n:bind($fn,$args,$type) {
	(: frame is bound late, exported function has to be called with frame again :)
	function($frame){
		function($vals) {
			$fn(a:fold-left-at($args,$frame,function($pre,$cur,$i){
				$cur($frame)($pre,$vals($i),$i)
			}))
		}
	}
};

declare function n:quote($value) {
	function($frame){
		$value
	}
};

declare function n:quote($frame,$name,$args) {
	function($frame){
		core:apply($frame,$name,$args)
	}
};

declare function n:quote-seq($value){
	function($frame) {
		n:seq($value,$frame)
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

declare function n:seq($value,$frame) {
	a:fold-left($value,$frame,function($pre,$cur){
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
