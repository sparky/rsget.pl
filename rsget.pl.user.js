// ==UserScript==
// @name		rsget.pl helper
// @namespace	http://rsget.pl
// @description	quickly add links to rsget.pl
// @include		http://*/*
// @include		https://*/*
// @include		file://*
// ==/UserScript==

(function(){
	function add_src( links, el_name )
	{
		try {
			var els = w.document.getElementsByTagName( el_name );
			for ( var i = 0; i < els.length; i++ ) {
				var el = els[ i ];
				if ( el.src )
					links.push( el.src );
			}
		} catch (e) {};
	}
	function add_window( links, w )
	{
		try {
			links.push( w.document.location.href );
		} catch ( e ) {};
		try {
			links.push( w.location.href );
		} catch ( e ) {};
		add_src( links, 'iframe' );
		add_src( links, 'frame' );
		try {
			var fel = w.frameElement;
			if ( fel )
				links.push( fel.src );
		} catch ( e ) {};

		var frames = w.frames;
		if ( frames ) {
			for ( var i = 0; i < frames.length; i++ ) {
				add_window( links, frames[ i ] );
			}
		}
	}
	function add_location()
	{
		var links = [];
		var w = unsafeWindow;
		add_window( links, w );
		while ( w != w.parent ) {
			w = w.parent;
			add_window( links, w );
		}

		window.setTimeout( send, 0, links.join( "\n" ) );
	}
	GM_registerMenuCommand("Add location to rsget.pl", add_location, null, null, "l");

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
		window.setTimeout( send, 0, links.join( "\n" ) );
	}
	GM_registerMenuCommand("Add links to rsget.pl", extract_links, null, null, "r");

	var server = GM_getValue( "server" );
	if ( server == null ) {
		server = prompt( "Specify rsget.pl location", "http://localhost:5666/" );
		GM_setValue( "server", server );
	}

	function send( text )
	{
		var uri = server + "add";

		var form = document.createElement( 'form' );
		form.setAttribute( 'action', uri );
		form.setAttribute( 'method', 'POST' );
		form.setAttribute( 'target', '_blank' );

		var ar = document.createElement( 'textarea' );
		ar.setAttribute( 'name', 'links' );
		ar.value = text;
		form.appendChild( ar );
		document.body.appendChild( form );
		form.submit();
	}
}());

// vim: ts=4:sw=4
