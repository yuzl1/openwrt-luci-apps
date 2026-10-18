'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';
'require poll';

const callApply = rpc.declare({ object: 'ddns-lite', method: 'apply' });
const callStatus = rpc.declare({ object: 'ddns-lite', method: 'status' });

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

return view.extend({
	load: function() {
		return uci.load('ddns-lite');
	},

	render: function() {
		let m, s, o;

		m = new form.Map('ddns-lite', _('DDNS Lite'),
			_('Lightweight DDNS built on ddns-scripts: pick a provider, enter the credentials and list the domains.'));

		s = m.section(form.TypedSection, 'settings', _('Configuration'));
		s.anonymous = true;

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

		o = s.option(form.Value, 'interface', _('Interface'),
			_('Interface used to read the public address, normally pppoe-wan.'));
		o.default = 'pppoe-wan';
		o.datatype = 'network';
		o.rmempty = false;

		o = s.option(form.DynamicList, 'domains', _('Domains'),
			_('One entry per domain, e.g. home.example.com.'));
		o.datatype = 'hostname';
		o.rmempty = false;

		o = s.option(form.Flag, 'ipv4', _('Update IPv4 (A record)'));
		o.default = '1';

		o = s.option(form.Flag, 'ipv6', _('Update IPv6 (AAAA record)'));
		o.default = '0';

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
