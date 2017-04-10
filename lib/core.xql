xquery version "3.1";

module namespace core="http://raddle.org/core";

import module namespace rdl="http://raddle.org/raddle" at "../content/raddle.xql";
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

declare function core:define($frame,$name,$def,$args,$type) {
    core:define($frame,$name,$def,$args,$type,"")
};

declare function core:define-private($frame,$name,$def,$args,$type,$body) {
    core:define($frame,$name,$def,$args,$type,$body,true())
};

declare function core:define($frame,$name,$def,$args,$type,$body) {
    core:define($frame,$name,$def,$args,$type,$body,false())
};

declare function core:cardinality($a){
        let $suffix := $a(1)
        let $card :=
            if($suffix eq "+") then
                "n.oneOrMore"
            else if($suffix eq "*") then
                "n.zeroOrMore"
            else if($suffix eq "?") then
                "n.zeroOrOne"
            else
                ""
        return 
            $card
};

declare function core:composite-type($composite) {
    string-join(array:flatten(array:for-each($composite,function($_){
        if($_ instance of xs:string) then
            core:cardinality([$_])
        else if($_("name") eq "") then
            concat("(",core:composite-type($_("args")),")")
        else
            concat(replace($_("name"),"core:","\$."),"(",core:cardinality([$_("suffix")]),")")
    })),",")
};

(: fixme :)
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


declare function core:define($frame,$name,$desc,$args,$type,$body,$private) {
	let $arity := array:size($args)
	let $last := $args($arity)
	let $has-rest-param := 
        if($last instance of map(xs:string,item()?)) then
            matches($last("args")(2),"^\.{3}")
        else
            matches($last,"^\.{3}")
	let $arity :=
	    if($has-rest-param) then
	        "n"
	    else
	        $arity
	return map:merge(($frame,
		map:entry("$functions",core:describe($frame("$functions"),$name,$desc,$args,$type)),
		map:entry("$exports",map:put($frame("$exports"),concat($name,"#",$arity),n:bind($body,$args,$type)($frame)))
	))
};

declare function core:anon($frame,$args,$type,$body) {
    n:bind($body,$args,$type)
};

declare function core:describe($frame,$name,$desc,$args,$type){
	map:put($frame,concat($name,"#",array:size($args)),
		map {
			"name": $name,
			"description": $desc
		}
	)
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
		core:anon($map,$keytype,$valtype,$body)
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
		core:anon(map{},$keytype,$valtype,$body)
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
			if(matches($name,"^core:[" || $rdl:ncname || "]+$")) then
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


declare function core:process-args($frame,$args,$caller,$nest){
	let $is-defn := $caller = ("core:define-private#6","core:define-private#5","core:define#6","core:define#5")
	let $is-anon := $caller eq "core:anon#4"
	let $is-iff := $caller eq "core:iff#3"
	let $is-typegen := matches($caller,"^core:(typegen|" || string-join(map:keys($core:typemap),"|") || ")")
	return
		a:fold-left-at($args,[],function($pre,$arg,$at){
			if($arg instance of array(item()?)) then
				let $is-thenelse := $is-iff and $at = (2,3)
				let $let-seq := core:find-let-seq($arg)
				let $is-let-ret := count($let-seq) > 0
				return
				    array:append($pre,
				        if($is-thenelse) then
				            (: the idea for transpile is that then/else may be seqs :)
						    let $val := core:process-args($frame,$arg,"",$nest)
						    let $s := array:size($val)
                            let $ret :=
                                if($s eq 0) then
                                    n:seq()
                                else if($s gt 1) then
                                    if($is-let-ret) then 
                                        core:let-ret($val,$let-seq,())
                    			    else
                    			        $val
                    			else
                    			    $val(1)
							return
							    $ret
						else
						    a:for-each-at($arg,function($_,$at){
								core:process-value($_,$frame,$at,$nest)
							})
					    )
			else if($arg instance of map(xs:string,item()?)) then
			    if(($is-defn and $at = 4) or 
			        ($is-anon and $at = 2)) then
			        (: is params! :)
				    array:append($pre,$arg("args"))
				else
				    let $is-thenelse := $is-iff and $at = (2,3)
				    let $is-body := ($is-defn and $at = 6) or ($is-anon and $at = 4)
				    return
				        if($is-body or $is-thenelse) then
				            (: check for let-ret-seq only if is-seq :)
				            let $args := $arg("args")
				            let $arg := 
				                if($is-body and $arg("name") eq ""  and 
				                array:size($args) eq 1 and 
				                $args(1) instance of map(xs:string,item())) then
				                    $args(1)
				                else
				                   $arg
				            let $is-seq := $arg("name") eq ""
				            let $ret :=
				                if($is-seq) then
    					            let $args := $arg("args")
    					            let $let-seq := core:find-let-seq($args)
                					let $is-let-ret := count($let-seq) > 0
                					let $val := core:process-args($frame,$args,"",$nest)
    							    let $s := array:size($val)
                                    return
                                        if($s eq 0) then
                                            ()
                                        else if($s gt 1) then
                                            if($is-let-ret) then 
                                                core:let-ret($val,$let-seq,())
                            			    else
                            			        $val
                            			else
                            			    $val(1)
                            	else
                            	    core:process-value($arg,$frame,$at)
							return
					            array:append($pre,$ret)
					    else
    					    if($arg("name") eq "" and $at gt 1 and $arg("call")) then
    					        let $val := n.call($pre($at - 1),core:process-value($arg,$frame,$at))
        					    return a:put($pre,$at - 1,$val)
        					else
        						array:append($pre,core:process-value($arg,$frame,$at,$nest))
			else if($arg eq ".") then
				array:append($pre,$nest)
			else if($arg eq "$") then
				array:append($pre,$frame)
			else if(matches($arg,"^\$[" || $rdl:ncname || "]+$")) then
				array:append($pre,if(matches($arg,"^\$\p{N}")) then
				    (: numeric var reference :)
					replace($arg,"^\$","\$_")
				else
					core:convert($arg,$frame))
			else if(($is-defn or $is-typegen) and $at eq 2) then
			    (: escape proper names :)
				array:append($pre,$arg)
			else if(matches($arg,"^_[" || $rdl:suffix || "]?$")) then
			    (: wildcard variable :)
				array:append($pre,replace($arg,"^_","_" || $frame("$at")))
			else
				array:append($pre,core:convert($arg,$frame))
		})
};

(: this will actually evaluate stuff :)
declare function core:process-value($value,$frame,$at,$nest){
	if($value instance of map(xs:string,item()?)) then
		let $name := $value("name")
		let $args := $value("args")
		let $s := if(map:contains($value,"args")) then array:size($args) else 0
		return
	        if(matches($name,"^core:[" || $rdl:ncname || "]+$")) then
				let $local := replace($name,"^core:","")
				let $is-type := $local = map:keys($core:typemap)
				let $is-native := $core:native-ops = $local
				let $s := if($is-type or $is-native) then $s + 1 else $s
				let $is-defn := $local = ("define","define-private","anon")
				let $is-fn := 
				    ($is-defn and ($s eq 6 or $s eq 5)) or 
				    ($local eq "anon" and $s eq 4) or 
				    ($local eq "interop")
(:				    or :)
(:				    ($local eq "iff"):)
				let $let-ret :=
				    if($is-type and $s gt 1) then
				        let $_ := $args($s - 1)
				        return
				            if($_ instance of map(xs:string,item()?) and $_("name") eq "") then
				                core:find-let-seq($_("args"))
				            else
				                ()
				    else
				        ()
				let $args := core:process-args($frame,$args,concat($name,"#",$s),$nest)
				let $args :=
					if($is-type or $is-native) then
						(: TODO append suffix :)
						array:insert-before($args,1,$local)
					else
						$args
				let $args :=
					a:for-each-at($args,function($_,$i){
					    if($is-type and $i eq $s and count($let-ret) gt 0) then
					        concat("($ => {",core:let-ret($_,$let-ret,()),"})($.frame())")
				        else if($_ instance of array(item()?) and $is-fn eq false()) then
							concat("n.seq(",string-join(array:flatten($_),","),")")
						else
							$_
					})
				let $s := array:size($args)
				let $fn :=
					if($is-type) then
						(: call typegen/constructor :)
						let $a := $core:typemap($local)
						let $f := concat("core:typegen",if($a > 0) then $a else "")
						return function-lookup(QName("http://raddle.org/core", $f),$s)
					else if($is-native) then
						function-lookup(QName("http://raddle.org/core", "core:native"),$s)
					else
						function-lookup(QName("http://raddle.org/core", $name),$s)
				let $n := if(empty($fn)) then console:log(($name,"#",$s,":",$args)) else ()
				let $ret := apply($fn,$args)
				return
				        $ret
			else if($name eq "") then
			    let $cx := core:find-context-item($args)
				let $args := a:for-each(core:process-args($frame,$args),function($_){
    					if($_ instance of array(item()?)) then
    						n.seq(array:flatten($_))
    					else
    						$_
    				})
				return
				    if($cx = ".") then
				        (: create anonymus function :)
				        concat("$_0 => ",string-join(array:flatten($args),""))
				    else
				        $args
			else
				let $args := core:process-args($frame,$args,concat($name,"#",$s),$nest)
				(: FIXME add check for seq calls :)
				let $ret :=
					a:fold-left-at($args,"",function($pre,$cur,$at){
						concat($pre,
							if($at>1) then "," else "",
							if($cur instance of array(item()?)) then
								concat("n.seq(",string-join(array:flatten($cur),","),")")
							else if($cur instance of map(xs:string,item()?)) then
								core:process-value($cur,$frame,$at,$nest)
							else
								$cur
						)
					})
				return
					(: FIXME add default fn ns prefix :)
					if(matches($name,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
						concat("n.call(",core:convert($name,$frame),",",$ret,")")
					else
						concat(core:anon-name($frame,$name,$s,"fn"),"(",$ret,")")
	else if($value instance of array(item()?)) then
		concat("n.seq(",core:process-tree($value,$frame),")")
	else if(matches($value,"^_[" || $rdl:suffix || "]?$")) then
		replace($value,"^_","\$_" || $at)
	else
		core:convert($value,$frame)
};

declare function core:convert($string,$frame){
    if(matches($string,"^n\.call")) then
		$string
	else if(matches($string,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
	    (: variable or function reference :)
		let $parts := tokenize(rdl:camel-case(replace($string,"#\p{N}+$","")),":")
		return
			if(count($parts) eq 1) then
				concat("$(",$env:QUOT,replace($parts,"^\$",""),$env:QUOT,")")
(:                $parts:)
			else if(matches($parts[1],concat("^\$?",$frame("$prefix")))) then
				replace($parts[last()],"\$","")
			else
				concat(replace($parts[1],"\$",""),".",$parts[2])
	else if(matches($string,concat("^(",$env:QUOT,"[^",$env:QUOT,"]*",$env:QUOT,")$"))) then
		n.string($string)
	else if(map:contains($core:auto-converted,$string)) then
		$core:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
			n.string($string)
		else if(matches($string,"\.")) then
			n.decimal($string)
		else
			n.integer($string)
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
		else if(matches($arg,concat("^\$[",$rdl:ncname,"]+$"))) then
			(: retrieve bound value :)
			$frame(replace($arg,"^\$",""))
		else if(matches($arg,concat("^[",$rdl:ncname,"]?:?[",$rdl:ncname,"]+#(\p{N}|N)+"))) then
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
			return n:eval(rdl:parse($src,$frame))($frame)
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
