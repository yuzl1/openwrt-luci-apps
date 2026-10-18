'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';
'require poll';

const callApply = rpc.declare({ object: 'ddns-lite', method: 'apply' });
const callStatus = rpc.declare({ object: 'ddns-lite', method: 'status' });

const V4_URLS = 'https://myip.ipip.net https://ddns.oray.com/checkip ' +
	'https://ip.3322.net https://4.ipw.cn https://v4.yinghualuo.cn/bejson';
const V6_URLS = 'https://speed.neu6.edu.cn/getIP.php https://v6.ident.me ' +
	'https://6.ipw.cn https://v6.yinghualuo.cn/bejson';

let map;

function renderStatus(status) {
	const running = status && status.running;
	const color = running ? 'green' : 'red';
	const text = running ? _('RUNNING') : _('NOT RUNNING');
	const log = (status && status.log) ? status.log : _('No recent log entries.');

	return E('div', {}, [
		E('p', {}, [ E('strong', { 'style': 'color:' + color }, text) ]),
		E('pre', { 'style': 'max-height:220px;overflow:auto;white-space:pre-wrap' }, log)
	]);
}

function familyOptions(s, family, defaultUrls, defaultSource) {
	let o;

	o = s.option(form.Flag, 'enabled', _('Enable'));
	o.default = '0';
	o.rmempty = false;

	o = s.option(form.ListValue, 'source', _('Get IP via'));
	o.value('network', _('Logical interface (network)'));
	o.value('interface', _('Network device (interface)'));
	o.value('web', _('URL check (web)'));
	o.value('script', _('Command (script)'));
	o.default = defaultSource;
	o.rmempty = false;

	o = s.option(form.TextValue, 'url', _('Check URLs'),
		_('Space separated, tried in order until an address is returned.'));
	o.default = defaultUrls;
	o.rows = 3;
	o.depends('source', 'web');

	o = s.option(form.Value, 'network', _('Logical interface'),
		_('OpenWrt interface name, e.g. pppoe-wan or wan6.'));
	o.default = 'pppoe-wan';
	o.depends('source', 'network');

	o = s.option(form.Value, 'interface', _('Network device'),
		_('Device name, e.g. br-lan, pppoe-wan or tailscale0.'));
	o.default = 'pppoe-wan';
	o.depends('source', 'interface');

	o = s.option(form.Value, 'script', _('Command'),
		_('Only stdout is used; the first matching address is taken.'));
	o.depends('source', 'script');

	o = s.option(form.DynamicList, 'domains', _('Domains'),
		_('One entry per domain, e.g. home.example.com.'));
	o.datatype = 'hostname';
	o.rmempty = false;
}

return view.extend({
	load: function() {
		return uci.load('ddns-lite');
	},

	render: function() {
		let m, s, o;

		m = new form.Map('ddns-lite', _('DDNS Lite'),
			_('Lightweight DDNS built on ddns-scripts: pick a provider, enter the credentials, then describe how IPv4 and IPv6 are obtained.'));

		s = m.section(form.NamedSection, 'settings', 'settings', _('Account'));

		o = s.option(form.ListValue, 'provider', _('DNS provider'));
		o.value('dnspod.cn', 'DNSPod / Tencent DNS (ID + token)');
		o.value('cloudflare.com-v4', 'Cloudflare (e-mail + API token)');
		o.value('aliyun.com', 'Aliyun DNS (AccessKey ID + secret)');
		o.value('freedns.afraid.org', 'FreeDNS');
		o.default = 'dnspod.cn';
		o.rmempty = false;

		o = s.option(form.Value, 'username', _('Account / ID'),
			_('DNSPod: numeric ID. Cloudflare: account e-mail. Aliyun: AccessKey ID.'));
		o.rmempty = false;

		o = s.option(form.Value, 'password', _('Token / secret'),
			_('DNSPod: API token. Cloudflare: API token. Aliyun: AccessKey secret.'));
		o.password = true;
		o.rmempty = false;

		o = s.option(form.Value, 'interval', _('Check interval (minutes)'));
		o.default = '10';
		o.datatype = 'uinteger';
		o.rmempty = false;

		o = s.option(form.DummyValue, '_status', _('Service status'));
		o.rawhtml = true;
		o.render = function() {
			return E('div', { 'class': 'cbi-value-field', 'id': 'ddns_lite_status' },
				E('em', {}, _('Collecting data ...')));
		};

		s = m.section(form.NamedSection, 'ipv4', 'ipv4', _('IPv4 (A record)'));
		familyOptions(s, 'ipv4', V4_URLS, 'web');

		s = m.section(form.NamedSection, 'ipv6', 'ipv6', _('IPv6 (AAAA record)'));
		familyOptions(s, 'ipv6', V6_URLS, 'interface');

		map = m;
		return m.render();
	},

	handleSaveApply: function(ev, mode) {
		return map.save().then(function() {
			return ui.changes.apply(mode == '0');
		}).then(function() {
			return callApply();
		}).then(function(res) {
			if (res && res.ok)
				ui.addNotification(null,
					E('p', {}, _('Applied %s DDNS entries.').format(res.entries)), 'info');
			else
				ui.addNotification(null,
					E('p', {}, (res && res.error) || _('Failed to apply the configuration.')), 'error');
		}).catch(function(err) {
			ui.addNotification(null,
				E('p', {}, _('Failed to apply: %s').format(err && err.message || err)), 'error');
		});
	},

	handleSave: null,
	handleReset: null,

	renderAfter: function() {
		poll.add(function() {
			return L.resolveDefault(callStatus(), {}).then(function(status) {
				const el = document.getElementById('ddns_lite_status');
				if (el)
					el.replaceChildren(renderStatus(status));
			});
		}, 10);
	}
});
