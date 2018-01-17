xquery version "3.1";

module namespace dawg="http://lagua.nl/dawg";
import module namespace console="http://exist-db.org/xquery/console";

declare function dawg:backtrack($path,$b){
    if(array:size($path) gt 0) then
        let $entry := array:head($path)
        return
            if($entry("_k") eq $b) then
                $entry("_v")
            else
                dawg:backtrack(array:tail($path),$b)
    else
        ()
};

declare function dawg:trav-loop($ret,$word,$length,$b,$path,$i){
    if(empty($ret) or ($ret instance of array(*) and array:size($ret) eq 0)) then
        ()
    else
        if($i lt $length) then
            let $i := $i + 1
            let $c := $word[$i]
            let $b := concat($b,$c)
            let $tmp := dawg:find($ret,$c,$b,$path)
        	let $ret := $tmp(1)
        	let $path := $tmp(2)
        	return
        		dawg:trav-loop($ret,$word,$length,$b,$path,$i)
        else
            let $ret :=
                if($ret instance of array(*)) then
                    if(array:size($ret) gt 0) then
                        $ret(1)
                    else
                        ()
                else
                    $ret
            return
                if($ret instance of map(*) and $ret("_k") eq $b) then
                    $ret("_v")
                else
                    let $entry := dawg:backtrack($path,$b)
                    return
                        if($entry) then
                            $entry
                        else
                            [$ret, $path]
};

declare function dawg:traverse($tmp,$buffer){
	let $ret := $tmp(1)
	let $path := if(array:size($tmp) gt 1) then $tmp(2) else []
	return dawg:trav-loop($ret,$buffer,count($buffer),"",$path,0)
};

declare function dawg:loop($entry, $ret, $cp, $word, $pos, $path){
    if(array:size($entry) gt 0) then
        let $a := array:head($entry)
        return
            let $is-entry := map:contains($a,"_v")
            return if($is-entry) then
                let $has :=
    		    if($is-entry) then
        		    dawg:match-pos($a,$pos,$cp)
    		    else
    		        false()
        		let $path :=
        		    if($has) then
        		        let $len := array:size($path)
        		        return
        		            if($len eq 0 or $path($len)("_v") ne $a("_v")) then
    	                        array:append($path,$a)
    	                    else
    	                        $path
    	            else
    	                $path
    	        let $ret :=
    	            if($has) then
    	                $a
    	            else
    	                array:filter($path,function($entry){
            		        dawg:match-pos($entry,$pos,$cp)
            		    })
            	return dawg:loop(array:tail($entry), $ret, $cp, $word, $pos, $path) 
            else
                if(map:contains($a,$cp)) then
		            [$a($cp),$path]
		        else
    		        dawg:loop(array:tail($entry), $ret, $cp, $word, $pos, $path) 
    else
        [$ret,$path]
};

declare function dawg:match-pos($entry,$pos,$cp){
    matches($entry("_k"),concat("^.{",$pos,"}[",replace($cp,"([\-\[\]\{\}\(\)\*\+\?\.\^\$\|])", "\\$1"),"]"))
};

declare function dawg:match-word($entry,$word){
    matches($entry("_k"),concat("^",replace($word,"([\-\[\]\{\}\(\)\*\+\?\.\^\$\|])", "\\$1")))
};

declare function dawg:find($entry,$cp,$word,$path){
    let $pos := string-length($word) - 1 return
	if($entry instance of array(*)) then
		dawg:loop($entry, $entry, $cp, $word, $pos, $path)
	else
	    if(map:contains($entry,"_v")) then
	        if(dawg:match-pos($entry,$pos,$cp)) then
	            let $len := array:size($path)
		        let $path :=
		            if($len eq 0 or $path($len)("_v") ne $entry("_v")) then
                        array:append($path,$entry)
                    else
                        $path
    			return [$entry,$path]
    		else
    		    [array:filter($path,function($entry){
    		        dawg:match-pos($entry,$pos,$cp)
    		    }),[]]
	    else
		    [$entry($cp),$path]
};
