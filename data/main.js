
function ajax_post( link, post, callback )
{
	var req = new XMLHttpRequest();

	req.onreadystatechange = function () {
		if ( req.readyState != 4 )
			return;
		
		var d = req.responseXML;
		callback( d ? d.lastChild.lastChild : null );
	};

	req.open( "POST", link, true );
	req.setRequestHeader( 'Content-Type', 'application/x-www-form-urlencoded' );
	req.setRequestHeader( 'Content-Length', post.length );
	req.setRequestHeader( 'Connection', 'close' );
	req.send( post );
}

function make_post( obj )
{
	var post = [];
	for ( var key in obj ) {
		post.push( escape( key ) + "=" + escape( obj[ key ] ) );
	}
	return post.join( "&" );
}

var last_update = {};
var update_uri = null;
function init_main()
{
	update_uri = "/update";
	window.setInterval( update, 750 );
}

function init_add( id )
{
	last_update.id = id;
	update_uri = "/add_update";
	window.setInterval( update, 800 );
}

function update()
{
	ajax_post( update_uri, make_post( last_update ), update_page );
	delete last_update.exec;
}

function update_page( body )
{
	if ( !body )
		return;
	{
		var script = body.lastChild;
		script.parentNode.removeChild( script );
		var update = eval( script.lastChild.nodeValue + "\nupdate" );
		for ( var key in update ) {
			last_update[ key ] = update[ key ];
		}
	}
	var ne;
	while ( ne = body.firstChild ) {
		ne.parentNode.removeChild( ne );
		if ( ne.nodeName == "#text" )
			continue;
		var id = ne.getAttribute( 'id' );
		var old = document.getElementById( id );
		if ( !old )
			continue;

		if ( id == "f_notify" )
			update_notify( ne, old );
		else
			old.parentNode.replaceChild( ne, old );
		if ( id == "f_dllist" || id == "f_addlist" || id == "f_listask" )
			add_DL_commands( ne );
	}
}

function update_notify( n_f, o_f )
{
	var nid = {};
	var n = n_f.lastChild;
	var o = o_f.lastChild;
	
	var node;
	while ( node = n.firstChild ) {
		var id = node.getAttribute( 'id' );
		nid[ id ] = node;
		node.parentNode.removeChild( node );
	}
	for ( var i = o.childNodes.length - 1; i >= 0; i-- ) {
		node = o.childNodes[ i ];
		var id = node.getAttribute( 'id' );
		if ( nid[ id ] ) {
			delete nid[ id ];
		} else {
			node.parentNode.removeChild( node );
		}
	}
	for ( var id in nid ) {
		node = nid[ id ];
		o.appendChild( node );
	}
}

function add_DL_commands( list )
{
	var divs = list.getElementsByTagName( 'div' );
	for ( var i = 0; i < divs.length; i++ ) {
		var div = divs[ i ];
		var cl = div.getAttribute( 'class' );
		if ( !cl || cl != 'tools' )
			continue;

		var spans = div.getElementsByTagName( 'span' );
		for ( var j = 0; j < spans.length; j++ ) {
			var span = spans[ j ];
			span.addEventListener( 'click', send_command, false );
		}
	}
}

function send_command( event )
{
	var cmd = this.firstChild.nodeValue;
	var target = this.parentNode.parentNode.getAttribute( 'id' );
	if ( cmd == "!REMOVE" ) {
		var c = confirm( "Remove " + target + " ?" );
		if ( !c )
			return;
	}
	last_update.exec = cmd + ":" + target;
}



var alerted = {};
function a( data )
{
	if ( alerted[ data ] )
		return;
	alerted[ data ] = 1;
	alert( data );
}
