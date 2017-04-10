xquery version "3.1";

module namespace rdl="http://raddle.org/raddle";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat-b.xql";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";
import module namespace env="http://raddle.org/env" at "../lib/env.xql";

declare variable $rdl:suffix := "\+\*\-\?";
declare variable $rdl:ncname := $xqc:ncname;

declare variable $rdl:chars := $rdl:suffix || $rdl:ncname || "\$%/#@\^:";

declare variable $rdl:paren-regexp := concat("(\)[",$rdl:suffix,"]?)|(",$xqc:operator-regexp,"|,)?([",$rdl:chars,"]*)(\(?)");
declare variable $rdl:protocol-regexp := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$";

declare variable $rdl:operators := map {
	300: "|",
	400: $env:AMP,
	501: "=eq=",
	502: "=ne=",
	503: "=lt=",
	504: "=le=",
	505: "=gt=",
	506: "=ge=",
	507: "=",
	508: "!=",
	509: "=<==",
	510: "=>==",
	511: "=<<=",
	512: "=>>=",
	513: "=<=",
	514: "=>=",
	600: "||",
	801: "+",
	802: "-",
	901: "*",
	902: "idiv",
	903: "div",
	904: "mod",
	1701: "+",
	1702: "-",
	1800: "!",
	2001: "[",
	2002: "]",
	2004: "[",
	2006: "{",
	2007: "}",
	2101: "array",
	2102: "attribute",
	2103: "comment",
	2104: "document",
	2105: "element",
	2106: "function",
	2107: "map",
	2108: "namespace",
	2109: "processing-instruction",
	2110: "text",
	2201: "array",
	2202: "attribute",
	2203: "comment",
	2204: "document-node",
	2205: "element",
	2206: "empty-sequence",
	2207: "function",
	2208: "item",
	2209: "map",
	2210: "namespace-node",
	2211: "node",
	2212: "processing-instruction",
	2213: "schema-attribute",
	2214: "schema-element",
	2215: "text",
	2501: "(:",
	2502: ":)",
	2600: ":"
};

declare variable $rdl:operator-map := map {
	300:"or",
	400:"and",
	501: "eq",
	502: "ne",
	503: "lt",
	504: "le",
	505: "gt",
	506: "ge",
	507: "geq",
	508: "gne",
	509: "gle",
	510: "gge",
	511: "precedes",
	512: "follows",
	513: "glt",
	514: "ggt",
	600: "concat",
	801: "add",
	802: "subtract",
	901: "multiply",
	1002: "union",
	1701: "plus",
	1702: "minus",
	1800: "for-each",
	1901: "select",
	2001: "filter",
	2003: "lookup",
	2004: "array",
	2701: "pair"
};

declare function rdl:map-put($map,$key,$val){
	map:merge(($map,map {$key : $val}))
};

declare function rdl:parse-strings($strings,$normalizer,$params) {
    (: TODO write wrapper function that adds strings to map uniquely, only incrementing per string (double entry) :)
    let $string := $strings("$%0")
	let $string := $normalizer($string,$params)
	let $parts := if(empty(tail($string))) then tokenize($string,";") else $string
	(: TODO detect RQL :)
	(: check for allowed/known filter operators up until any top level ops / aggregators :)
	(: if RQL, wrap with select(*,filter(...),top-level-ops) and aggregators :)
	return array:join(for-each($parts,function($block){
	    rdl:wrap(analyze-string($block,$rdl:paren-regexp)/fn:match,$strings,$params)
	}))
};

declare function rdl:normalize-query($query as xs:string?,$params){
    replace($query,"\s","")
};

declare function rdl:process-strings($strings,$ret,$index) {
    if(count($strings) eq 0) then
        $ret
    else
        let $head := head($strings)
        return
            if(name($head) eq "match") then
                let $string := $head/string()
                let $index := if(map:contains($ret,$string)) then $index else $index + 1
                let $key := "$%" || $index
                let $ret := map:put($ret, $key, concat($env:QUOT,rdl:clip-string($string),$env:QUOT))
                let $ret := map:put($ret,"$%0",concat($ret("$%0"),$key))
                return rdl:process-strings(tail($strings),$ret,$index)
            else
                let $ret := map:put($ret,"$%0",concat($ret("$%0"),$head/string()))
                return rdl:process-strings(tail($strings),$ret,$index)
};

declare function rdl:parse($query as xs:string?){
	rdl:parse($query,map {})
};

declare function rdl:parse($query as xs:string?,$params) {
    let $params := if(matches($query,"^\s*xquery\s+version")) then map:put($params,"$compat","xquery") else $params
    let $strings := rdl:process-strings(analyze-string($query,concat("('[^']*')|(",$env:QUOT,"[^",$env:QUOT,"]*",$env:QUOT,")"))/*,map { "$%0" : "" } , 1)
    let $params :=
        if($params("$compat") eq "xquery") then
            map:put(map:put($params,"$operators",$xqc:operators),"$operator-map",$xqc:operator-map)
        else if($params("$compat") eq "rql") then
            map:put(map:put($params,"$operators",$rdl:operators),"$operator-map",$rdl:operator-map)
        else
            $params
	return
    	rdl:parse-strings(
    		$strings,
    		if($params("$compat") eq "") then
    		    rdl:normalize-query#2
    		else
	            xqc:normalize-query#2,
    		$params
    	)
};

declare function rdl:clip-string($str as xs:string) {
	substring($str,2,string-length($str)-2)
};

declare function rdl:value-from-strings($val as xs:string?,$strings) {
	if($val) then
    	if(matches($val,"\$%[0-9]+")) then
    		$strings($val)
    	else
    		$val
    else
        ""
};

declare function rdl:upsert($ret,$index,$val) {
    if(array:size($ret) lt $index) then
        array:append($ret,[$val])
    else
        a:put($ret,$index,array:append($ret($index),$val))
};

declare function rdl:wrap-qname($args) {
    if($args instance of map(xs:string,item()?)) then
        map {
            "name" := $args("name"),
            "args" := array:for-each($args("args"),function($arg){
                if($arg instance of xs:string and matches($arg,$xqc:qname)) then
                    map {
                        "name" := "core:select",
                        "args" := [".",$arg],
                        "suffix" := ""
                    }
                else
                    rdl:wrap-qname($arg)
            }),
            "suffix" := ""
        }
    else if($args instance of array(item()?)) then
        array:for-each($args,function($arg){
            if($arg instance of xs:string and matches($arg,$xqc:qname)) then
                map {
                    "name" := "core:select",
                    "args" := [".",$arg],
                    "suffix" := ""
                }
            else
                rdl:wrap-qname($arg)
        })
    else
        $args
};

declare function rdl:find-context-item($value) {
	if(array:size($value) eq 0) then
		()
	else
		let $cx := array:filter($value,function($_) {
	        $_ instance of xs:string and matches($_,"^\.$")
	    })
	    return
	        if(array:size($cx) gt 0) then
	            array:flatten($cx)
	        else
		        array:flatten(
        			a:for-each-at($value,function($_,$at){
        				if($_ instance of map(xs:string, item()?)) then
        					(: only check strings in sequence :)
        					if($_("name") = ("","last","fn:last")) then
    					        ()
        					else if($_("name") eq "core:filter") then
    					        rdl:find-context-item([$_("args")(1)])
        					else
        					    rdl:find-context-item($_("args"))
        				else
        				    ()
        			})
        		)
};

declare function rdl:wrap($match,$strings,$params){
	rdl:wrap($match,$strings,$params,[])
};

declare function rdl:wrap($match,$strings,$params,$ret){
	rdl:wrap($match,$strings,$params,$ret,1)
};

declare function rdl:wrap($match,$strings,$params,$ret,$depth){
	rdl:wrap($match,$strings,$params,$ret,$depth,false())
};

declare function rdl:wrap($match,$strings,$params,$ret,$depth,$was-comma){
    if(empty($match)) then
        $ret(1)
    else
        let $group := head($match)/fn:group
        let $rest := tail($match)
	    let $separator := $group[@nr=2]/string()
	    let $value := rdl:value-from-strings($group[@nr=3]/string(),$strings)
	    let $is-comma := matches($separator,",")
	    let $is-op := $is-comma = false() and matches($separator,$xqc:operator-regexp || "+")
	    let $op := if($is-op) then xqc:op-num($separator) else ()
		return if($group/@nr = 4) then
		    (: if operator, the remainder should be wrapped around ret, depending on operator precedence :)
		    let $ret := 
    		    if($is-comma) then
    		        rdl:upsert($ret,$depth,map { "name" := $value, "args" := [], "suffix" := ""})
    		    else if($is-op) then
    		        let $operator := xqc:to-op($op,$params)
    		        let $dest := if(array:size($ret) lt $depth) then [] else $ret($depth)
    		        let $len := array:size($dest)
    				let $last := if($len gt 0) then $dest($len) else ()
    				let $filter := $op eq 2001
    				let $filter-context :=
    				    if($filter and $depth gt 1) then
        				    let $prev := $ret($depth - 1)
        				    let $s := array:size($prev)
        				    return $prev($s)
    				    else
    				        ()
    				let $select-filter := $filter-context instance of map(xs:string,item()?) and $filter-context("op") eq 1901
                    return
                        if($op = $xqc:lr-op or ($filter and $select-filter eq false())) then
                            let $args := if($op = (1901,2001) and $value eq "") then [] else [map {"name" := $value,"args" := [], "suffix" := ""}]
                            let $prev-op := 
                                if($last instance of map(xs:string,item()?) and map:contains($last,"op")) then 
                                    $last("op")
                                else
                                    ()
                            let $has-preceding-op := exists($prev-op) and $prev-op = $xqc:lr-op
                            let $is-unary-op := 
            				    if($op idiv 100 = (8,17)) then
            				        $was-comma or $has-preceding-op
        				        else
        				            false()
        	                let $preceeds := $has-preceding-op and round($op) gt round($prev-op)
                            return
                                if($is-unary-op) then
                                    let $operator := xqc:to-op(xqc:unary-op($op),$params)
                                    let $dest :=
                            	        if($preceeds and array:size($last("args")) lt 2) then
                                			a:put($dest,$len,map:put($last,"args",[$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne ""}]))
                            	        else
                    	                array:append($dest,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne ""})
                    	            return a:put($ret,$depth,$dest)
                                else if($preceeds) then
                                    let $args := array:insert-before($args,1,$last("args")(2))
                                    let $dest := a:put($dest,$len,map:merge(($last,map {
                                        "args" := [$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op }],
                                        "nest" := true()
                                    })))
                                    return a:put($ret,$depth,$dest)
                                else
                                    let $args := array:insert-before($args,1,$last)
                                    let $dest := a:put($dest,$len,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne "" })
                                    return a:put($ret,$depth,$dest)
                        else
                            if($value ne "") then
                                let $args := [$last,map { "name" := $value, "args" := [], "suffix" := ""}]
                                let $dest := a:put($dest,$len,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne ""})
        				        return a:put($ret,$depth,$dest)
                            else
                                rdl:upsert($ret,$depth,map { "name" := $operator, "args" := [], "suffix" := "", "op" := $op})
    		    else
    		        rdl:upsert($ret,$depth,map { "name" := $value, "args" := [], "suffix" := "", "call" := array:size($ret) ge $depth and $value eq ""})
    		return rdl:wrap($rest,$strings,$params,$ret,$depth+1,$is-comma and $value eq "")
		else if($value or $is-comma or $is-op) then
		    let $ret :=
		        if($is-op) then
		            if(array:size($ret) lt $depth) then
		                (: single unary :)
		                let $op := xqc:unary-op($op)
		                let $args := if($value ne "") then [$value] else []
        				let $operator := xqc:to-op($op,$params)
        				return array:append($ret,[map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op}])
		            else
    		            let $dest := $ret($depth)
                        let $len := array:size($dest)
        				let $last := $dest($len)
        				let $prev-op := 
                            if($last instance of map(xs:string,item()?) and map:contains($last,"op")) then 
                                $last("op")
                            else
                                ()
        				let $has-preceding-op := exists($prev-op) and $prev-op = $xqc:lr-op
    	                let $is-unary-op := 
        				    if($op idiv 100 = (8,17)) then
        				        $was-comma or $has-preceding-op
    				        else
    				            false()
    				    let $preceeds := $has-preceding-op and round($op) gt round($prev-op)
        				let $op :=
                    		if($is-unary-op) then
                    			xqc:unary-op($op)
                    		else
                    			$op
                    	let $operator := xqc:to-op($op,$params)
                    	let $dest := 
                    	    if($is-unary-op) then
                    	        let $args :=
                    				if($value ne "") then
                    					[$value]
                    				else
                    					[]
                    			return
                        	        if($preceeds and array:size($last("args")) lt 2) then
                            			a:put($dest,$len,map:put($last,"args",[$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op}]))
                        	        else
                    	                array:append($dest,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op})
                	        else if($preceeds) then
                	            let $args := [$last("args")(2)]
                    			let $args :=
                    				if($value ne "") then
                    					array:append($args,$value)
                    				else
                    					$args
                    			let $next := map:put($last,"args",[$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op}])
                				return a:put($dest,$len,$next)
                	        else
                			    let $args := if($value ne "") then [$last,$value] else [$last]
                				return a:put($dest,$len,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op})
        				return
    		                a:put($ret,$depth,$dest)
		        else if($value ne "") then
		            rdl:upsert($ret,$depth,$value)
		        else
		            $ret
			return rdl:wrap($rest,$strings,$params,$ret,$depth,$is-comma and $value eq "")
		else if($group/@nr = 1) then
		    if(array:size($ret) lt $depth or $depth lt 2) then
		        let $suffix := replace($group/string(),"\)","")
		        let $ret :=
		            if($suffix ne "") then
        	            let $dest := $ret($depth - 1)
            		    let $len := array:size($dest)
            		    let $last := map:put($dest($len),"suffix",$suffix)
            		    let $dest := a:put($dest,$len,$last)
        		        return a:put($ret,$depth - 1, $dest)
        		    else
        		        $ret
		        return rdl:wrap($rest,$strings,$params,$ret,$depth - 1) 
		    else
	            let $args := $ret($depth)
	            let $dest := $ret($depth - 1)
    		    let $len := array:size($dest)
    		    let $last := $dest($len)
    		    let $s := array:size($last("args"))
	            let $next := if($s gt 0) then $last("args")($s) else ()
	            let $nest := $next instance of map(xs:string,item()?) and ($last("nest") or $next("name") eq "")
	            let $op := if($nest) then $next("op") else if($last instance of map(xs:string,item()?)) then $last("op") else ()
	            let $args :=
	                if($nest) then
	                    let $ns := array:size($next("args"))
    		            let $maybeseq := if($ns gt 0) then $next("args")($ns) else ()
    		            let $is-seq := $maybeseq instance of map(xs:string,item()?) and $op ne 1901 and map:contains($maybeseq,"op") eq false()
    		            return
    		                if($is-seq) then
    		                    a:put($next("args"),$ns,map:put($maybeseq,"args",array:join(($maybeseq("args"),$args))))
    		                else
    		                    array:join(($next("args"),$args))
    		        else
    		            array:join(($last("args"),$args))
    		    (:
	            this is for the implementation of xquery only
	            if no dot is found, look for a qname (or @qname)
	            or no qname is found expect fn:position instead
	            TODO: check for axis::qname
	            :)
	            let $args :=
	                if($op eq 1901) then
	                    array:for-each($args,function($_){
	                        if($_ instance of map(xs:string,item()?)) then
	                            if($_("name") eq "") then
	                                $_
	                            else if(rdl:find-context-item([$_]) = ".") then
	                                map { "name" := "", "args" := [$_], "suffix" := "" }
	                            else
	                                $_
	                        else
	                            $_
	                    })
	                else if($op eq 2001) then
	                    let $is-implicit := array:size($args) eq 1
	                    let $first := 
	                        if($is-implicit) then
	                            "."
	                        else
	                            let $first := $args(1)
	                            return
                                    if(rdl:find-context-item([$first]) = ".") then $first else rdl:wrap-qname([$first])(1)
                        
                        let $second :=
                            if($is-implicit) then
                                $args(1)
                            else
                                $args(2)
                        let $second := if(rdl:find-context-item([$second]) = ".") then $second else rdl:wrap-qname([$second])(1)
                        let $second := if(rdl:find-context-item([$second]) = ".") then $second else map {
                            "name" := "core:geq",
                            "args" := [map {
                                "name" := "position",
                                "args" := ["."],
                                "suffix" := ""
                            },$second],
                            "suffix" := ""
                        }
                        let $second :=
                            map {
                                "name" := "", 
                                "args" := [$second],
                                "suffix" := ""
                            }
                        return [$first, $second]
	                else
	                    $args
	            let $dest :=
    		        if($nest) then
    		            let $val := map { "name" := $next("name"), "args" := $args, "suffix" := "" }
    		            return a:put($dest,$len,map { "name" := $last("name"), "args" := a:put($last("args"),$s,$val), "suffix" := replace($group/string(),"\)",""), "op" := $last("op"), "nest" := $last("nest")})
    		        else
    		            let $val := map { "name" := $last("name"), "args" := $args, "suffix" := replace($group/string(),"\)",""), "call" := $last("call")}
    		            return a:put($dest,$len,$val)
		        return rdl:wrap($rest,$strings,$params,array:append(array:subarray($ret,1,$depth - 2),$dest),$depth - 1)
		else
	        $ret(1)
};

declare function rdl:stringify($a,$params){
	rdl:stringify($a,$params,true())
};

declare function rdl:stringify($a,$params,$top){
	let $s := array:size($a)
	return
		a:fold-left-at($a,"",function($acc,$t,$i){
		    let $is-map := $t instance of map(xs:string?,item()?)
			let $ret :=
				if($is-map) then
					concat($t("name"),"(",string-join(rdl:stringify($t("args"),$params,false()),","),")",if($t("suffix") instance of xs:string) then $t("suffix") else "")
				else if($t instance of array(item()?)) then
					concat("(",rdl:stringify($t,$params,false()),")")
				else
					$t
			return concat($acc,
			    if($i gt 1) then
		            if($top) then
		                concat(";",$env:LF)
		            else if($is-map and $t("call")) then
			            ""
			        else
		                ","
			    else
			        "",$ret)
		})
};

declare function rdl:clip($name){
	if(matches($name,concat("^",$env:QUOT,".*",$env:QUOT,"$"))) then rdl:clip-string($name) else $name
};

declare function rdl:camel-case($name){
	let $p := tokenize($name,"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};

declare function rdl:capitalize($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};