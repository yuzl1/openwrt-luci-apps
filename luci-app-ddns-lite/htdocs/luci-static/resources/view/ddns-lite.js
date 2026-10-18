'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';
'require poll';
'require network';

const callApply = rpc.declare({ object: 'ddns-lite', method: 'apply' });
const callStatus = rpc.declare({ object: 'ddns-lite', method: 'status' });
const callProviders = rpc.declare({ object: 'ddns-lite', method: 'providers' });
const callServiceControl = rpc.declare({ object: 'ddns-lite', method: 'service_control', params: ['action'] });

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
		E('div', { 'style': 'margin:0.5em 0' }, [
			actionButton(_('Start'), 'start', 'cbi-button-positive'),
			' ',
			actionButton(_('Stop'), 'stop', 'cbi-button-negative'),
			' ',
			actionButton(_('Restart'), 'restart', 'cbi-button-action')
		]),
		E('pre', { 'style': 'max-height:220px;overflow:auto;white-space:pre-wrap' }, log)
	]);
}

function serviceAction(action) {
	return callServiceControl(action).then(function(res) {
		if (res && res.ok)
			ui.addNotification(null, E('p', {}, _('Service %s requested.').format(action)), 'info');
		else
			ui.addNotification(null, E('p', {}, (res && res.error) || _('Service action failed.')), 'error');
	}).then(function() {
		return new Promise(function(resolve) {
			window.setTimeout(resolve, 1500);
		});
	}).then(function() {
		return refreshStatus();
	}).catch(function(err) {
		ui.addNotification(null,
			E('p', {}, _('Service action failed: %s').format(err && err.message || err)), 'error');
	});
}

function actionButton(label, action, style) {
	return E('button', {
		'class': 'btn cbi-button ' + style,
		'click': function(ev) {
			ev.preventDefault();
			return serviceAction(action);
		}
	}, label);
}

function attachProviderFilter() {
	const filter = document.getElementById('ddns_provider_filter');
	if (!filter || filter.getAttribute('data-bound') === '1')
		return;

	const select = document.querySelector('select[id$=".provider"]');
	if (!select)
		return;

	filter.setAttribute('data-bound', '1');
	filter.addEventListener('input', function() {
		const q = this.value.trim().toLowerCase();

		Array.prototype.forEach.call(select.options, function(opt) {
			const match = !q ||
				String(opt.value).toLowerCase().indexOf(q) >= 0 ||
				opt.text.toLowerCase().indexOf(q) >= 0;
			opt.hidden = !match;
			opt.style.display = match ? '' : 'none';
		});
	});
}

function refreshStatus() {
	return L.resolveDefault(callStatus(), {}).then(function(status) {
		const el = document.getElementById('ddns_lite_status');
		if (el)
			el.replaceChildren(renderStatus(status));
	});
}

const PROVIDER_LABELS = {
	'dnspod.cn': 'DNSPod / Tencent DNS (ID + token)',
	'cloudflare.com-v4': 'Cloudflare (e-mail + API token)',
	'aliyun.com': 'Aliyun DNS (AccessKey ID + secret)',
	'freedns.afraid.org': 'FreeDNS',
	'no-ip.com': 'No-IP',
	'dynv6.com': 'dynv6'
};

const DOMAIN_RE = /^(\*\.)?([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$/;
const HOSTZONE_RE = /^([A-Za-z0-9*]([A-Za-z0-9.*-]{0,61}[A-Za-z0-9*])?)@([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$/;

function validDomain(value) {
	const v = (value || '').trim();
	return DOMAIN_RE.test(v) || HOSTZONE_RE.test(v);
}

function fillList(o, items, fallbacks) {
	const seen = {};

	(items || []).forEach(function(item) {
		const name = (typeof item === 'string') ? item : item.name;
		const label = (typeof item === 'string') ? item : (item.label || item.name);
		if (!name || seen[name])
			return;
		seen[name] = true;
		o.value(name, label);
	});

	(fallbacks || []).forEach(function(name) {
		if (seen[name])
			return;
		seen[name] = true;
		o.value(name, name);
	});
}

function labelList(entries) {
	return (entries || []).map(function(entry) {
		const name = entry.getName ? entry.getName() : String(entry);
		let addrs = [];

		try { addrs = entry.getIPAddrs ? entry.getIPAddrs() : []; } catch (e) {}
		if (!addrs.length) {
			try { addrs = entry.getIP6Addrs ? entry.getIP6Addrs() : []; } catch (e) {}
		}

		const addr = addrs.length ? addrs[0] : '';
		return { name: name, label: addr ? (name + '[' + addr + ']') : name };
	});
}

function familyOptions(s, family, defaultUrls, defaultSource, networks, devices,
		defaultNetwork, defaultDevice) {
	let o;

	o = s.option(form.Flag, 'enabled', _('Enable'));
	o.default = '0';
	o.rmempty = false;

	o = s.option(form.ListValue, 'source', _('Get IP via'));
	o.value('network', _('Logical interface (network) - recommended'));
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

	o = s.option(form.ListValue, 'network', _('Logical interface'),
		_('netifd interface (wan, wan6, pppoe-wan, lan) with its current address.'));
	o.depends('source', 'network');
	fillList(o, networks, [defaultNetwork, 'wan', 'wan6', 'pppoe-wan', 'lan']);
	o.default = defaultNetwork;

	o = s.option(form.ListValue, 'interface', _('Network device'),
		_('Linux device (br-lan, pppoe-wan, tailscale0) with its current address.'));
	o.depends('source', 'interface');
	fillList(o, devices, [defaultDevice, 'pppoe-wan', 'br-lan']);
	o.default = defaultDevice;

	o = s.option(form.Value, 'script', _('Command'),
		_('Only stdout is used; the first matching address is taken.'));
	o.depends('source', 'script');

	o = s.option(form.DynamicList, 'domains', _('Domains'),
		_('One entry per domain. Plain names (home.example.com), wildcards (*.example.com) and the explicit DNSPod form host@zone.tld are accepted.'));
	o.validate = function(section_id, value) {
		if (value == null || value === '')
			return true;
		return validDomain(value) ? true
			: _('Enter home.example.com, *.example.com or host@example.com');
	};
	o.rmempty = true;
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('ddns-lite'),
			L.resolveDefault(callProviders(), {}),
			L.resolveDefault(network.getDevices(), []),
			L.resolveDefault(network.getNetworks(), [])
		]);
	},

	render: function(data) {
		let m, s, o;
		const providers = (data && data[1] && data[1].providers) || [];
		const devices = labelList(data && data[2]);
		const networks = labelList(data && data[3]);

		m = new form.Map('ddns-lite', _('DDNS Lite'),
			_('Lightweight DDNS built on ddns-scripts: pick a provider, enter the credentials, then describe how IPv4 and IPv6 are obtained.'));

		s = m.section(form.NamedSection, 'settings', 'settings', _('Account'));

		o = s.option(form.DummyValue, '_provider_filter', _('Find provider'));
		o.rawhtml = true;
		o.render = function() {
			return E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title', 'for': 'ddns_provider_filter' }, _('Find provider')),
				E('div', { 'class': 'cbi-value-field' }, [
					E('input', {
						'type': 'text',
						'id': 'ddns_provider_filter',
						'class': 'cbi-input-text',
						'placeholder': _('Type to filter the provider list')
					}),
					E('div', { 'class': 'cbi-value-description' },
						_('Filters the DNS provider list below without changing the selection.'))
				])
			]);
		};

		o = s.option(form.ListValue, 'provider', _('DNS provider'));
		providers.forEach(function(p) {
			o.value(p, PROVIDER_LABELS[p] || p);
		});
		if (!providers.length)
			o.value('dnspod.cn', 'DNSPod / Tencent DNS (ID + token)');
		else {
			const saved = uci.get('ddns-lite', 'settings', 'provider');
			if (saved && providers.indexOf(saved) < 0)
				o.value(saved, saved + ' (' + _('package not installed') + ')');
		}
		o.default = 'dnspod.cn';
		o.rmempty = false;
		o.description = _('Only providers with an installed ddns-scripts service are listed; ' +
			'install the matching package (for example ddns-scripts-dnspod) to add more.');

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
		familyOptions(s, 'ipv4', V4_URLS, 'network', networks, devices,
			'wan', 'pppoe-wan');

		s = m.section(form.NamedSection, 'ipv6', 'ipv6', _('IPv6 (AAAA record)'));
		familyOptions(s, 'ipv6', V6_URLS, 'network', networks, devices,
			'wan6', 'pppoe-wan');

		map = m;
		const rendered = m.render();

		window.setTimeout(refreshStatus, 200);
		window.setTimeout(attachProviderFilter, 300);
		poll.add(refreshStatus, 10);

		return rendered;
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
	handleReset: null
});
