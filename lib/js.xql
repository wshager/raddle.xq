xquery version "3.1";

module namespace js="http://raddle.org/javascript";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $js:typemap := map {
	"integer": "Number",
	"string": "String"
};

declare function js:module($prefix,$ns,$desc) {
	concat("/*module namespace ", $prefix, "=&quot;", $ns, "&quot;;&#10;",$desc,"*/")
};

declare function js:import($prefix,$ns) {
	concat("import * as ", $prefix, " from &quot;", $ns, "&quot;")
};

declare function js:import($prefix,$ns,$loc) {
	concat("import * as ", $prefix, " from &quot;", $loc, "&quot;")
};


declare function js:cc($name){
	let $p := tokenize(replace($name,"#","_"),"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};


declare function js:define($name,$def,$args,$type,$body) {
	let $args := array:for-each($args,function($_){
		let $n := console:log($_) return
		if($_ instance of array(item()?)) then
			apply(js:typegen#4,$_)
		else
			"$" || $_
	})
	let $check := string-join(array:flatten(array:for-each($args,function($_){
		concat("core.typecheck(",string-join(tokenize(replace($_,"^([^ ]*) /\* (\p{L}+)([\?\*\+]?) \*/$","$2,$1,$3"),",")[. ne ""],","),")")
	})),";")
	return concat("export function ",js:cc(tokenize($name,":")[last()]),"(",string-join(array:flatten($args),","),") ",$type," { ",$check,"; return ",$body," };")
};

declare function js:function($args,$type,$body) {
	let $args := array:for-each($args,function($_){
		let $n := console:log($_) return
		apply(js:typegen#4,$_)
	})
	let $check := string-join(array:flatten(array:for-each($args,function($_){
		concat("core.typecheck(",string-join(tokenize(replace($_,"^([^ ]*) /\* (\p{L}+)([\?\*\+]?) \*/$","$2,$1,$3"),",")[. ne ""],","),")")
	})),";")
	return concat("function(",string-join(array:flatten($args),","),") ",$type," { ",$check,"; return ",$body," };")
};

declare function js:typegen($type,$name,$val,$suffix) {
	let $type := $js:typemap($type)
	return
		if($val) then
			"let " || $name || " = core.typecheck(" || $type || "," || $val || "," || $suffix || ");"
		else
			$name || " /* " || $type || $suffix || " */"
};
