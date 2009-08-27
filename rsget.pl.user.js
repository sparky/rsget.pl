// ==UserScript==
// @name		rsget.pl helper
// @namespace	http://rsget.pl/
// @description	quickly add links to rsget.pl
// @include		http://*.*/*
// ==/UserScript==

(function(){

	var hostname = document.location.hostname;
	function add_links( links, node )
	{
		if ( ! node.nodeName )
			return;
		var text;
		if ( node.nodeName == 'A' ) {
			text = node.getAttribute( 'href' );
		} else if ( node.nodeName == '#text' ) {
			text = node.nodeValue;
		}
		if ( ! text )
			return;
		var m = text.match( /http:\/\/\S+\/[\w#!:.?+=&%@!\-\/]+/g );
		if ( !m )
			return;
		for ( var i = 0; i < m.length; i++ ) {
			var href = m[ i ];
			if ( href.match( "^http://[^/]*" + hostname + "(:\d+)?/" ) )
				continue;
			var found = 0;
			for ( var j = 0; j < links.length; j++ ) {
				if ( links[ j ] == href ) {
					found = 1;
					break;
				}
			}
			if ( ! found )
				links.push( href );
		}
	}

	function crawl_nodes( links, node, end )
	{
		while ( node != end ) {
			if ( node.firstChild ) {
				node = node.firstChild;
			} else if ( node.nextSibling ) {
				node = node.nextSibling;
			} else {
				do {
					node = node.parentNode;
					if ( node == end )
						return;
				} while ( ! node.nextSibling );
				node = node.nextSibling;
			}
			if ( node == end )
				return;
			add_links( links, node );
		}
	}

	function fake_text( text )
	{
		return { nodeName: '#text', nodeValue: text };
	}

	function extract_links()
	{
		var range;
		try {
			range = window.getSelection().getRangeAt( 0 );
		} catch ( e ) {}
		var links = new Array;

		if ( !range || range.collapsed ) {
			crawl_nodes( links, document.body, document );
		} else {
			var node = range.startContainer;
			var end = range.endContainer;
			
			if ( node == end ) {
				add_links( links, fake_text( node.nodeValue.substring( range.startOffset, range.endOffset ) ) );
			} else {
				if ( node.nodeValue )
					add_links( links, fake_text( node.nodeValue.substr( range.startOffset ) ) );
				crawl_nodes( links, node, end );
				if ( end.nodeValue )
					add_links( links, fake_text( end.nodeValue.substr( 0, range.endOffset ) ) );
			}
		}
		send( "links=" + escape( links.join( "\n" ) ) );
	}
	GM_registerMenuCommand("Add links to rsget.pl", extract_links);

	function add_comment()
	{
		var range;
		var sel;
		try {
			sel = window.getSelection();
			range = sel.getRangeAt( 0 );
		} catch ( e ) {}
		var links = new Array;

		if ( !range || range.collapsed ) {
			alert( "Can create comments only from selection" );
			return;
		}
		send( "comment=" + escape( sel ) );
	}
	GM_registerMenuCommand("Add comments to rsget.pl", add_comment);


	function onload( req )
	{
		GM_log( req.responseText );
	}

	function onerror( req )
	{
	}

	function send( post )
	{
		var server = GM_getValue( "server", "http://localhost:8080/" );
		GM_setValue( "server", server );
		var uri = server + "add";

		GM_xmlhttpRequest( {
			method: "POST",
			url: uri,
			headers: { 'Content-type': 'application/x-www-form-urlencoded' },
			data: post,
			onload: onload,
			onerror: onerror
		} );
	}
}());

// vim: ts=4:sw=4
