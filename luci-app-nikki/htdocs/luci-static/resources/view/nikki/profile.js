'use strict';
'require form';
'require view';
'require uci';
'require tools.nikki as nikki';

const hwidAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const hwidLength = 16;

function randomHWID() {
    const bytes = new Uint8Array(hwidLength);
    window.crypto.getRandomValues(bytes);
    let value = '';
    for (const byte of bytes) {
        value += hwidAlphabet.charAt(byte % hwidAlphabet.length);
    }
    return value;
}

function headerValueValidator(section_id, value) {
    if (!value) {
        return true;
    }
    if (!/^[\x20-\x7E]*$/.test(value)) {
        return _('Printable ASCII characters only');
    }
    return true;
}

return view.extend({
    load: function () {
        return Promise.all([
            uci.load('nikki'),
            L.resolveDefault(nikki.hwidInfo(), {})
        ]);
    },
    render: function (data) {
        let m, s, o, so;

        const hwidInfo = data[1] ?? {};
        const hwidDefaults = {
            hwid_value: hwidInfo.hwid ?? '',
            hwid_device_os: hwidInfo.device_os ?? 'OpenWrt',
            hwid_ver_os: hwidInfo.ver_os ?? '',
            hwid_device_model: hwidInfo.device_model ?? ''
        };

        m = new form.Map('nikki');

        s = m.section(form.NamedSection, 'config', 'config', _('Profile'));

        o = s.option(form.FileUpload, '_upload_profile', _('Upload Profile'));
        o.browser = true;
        o.enable_download = true;
        o.root_directory = nikki.profilesDir;
        o.write = function (section_id, formvalue) {
            return true;
        };

        s = m.section(form.GridSection, 'subscription', _('Subscription'));
        s.addremove = true;
        s.anonymous = true;
        s.sortable = true;
        s.modaltitle = _('Edit Subscription');

        o = s.option(form.Value, 'name', _('Subscription Name'));
        o.rmempty = false;

        o = s.option(form.Value, 'used', _('Used'));
        o.modalonly = false;
        o.optional = true;
        o.readonly = true;

        o = s.option(form.Value, 'total', _('Total'));
        o.modalonly = false;
        o.optional = true;
        o.readonly = true;

        o = s.option(form.Value, 'expire', _('Expire At'));
        o.modalonly = false;
        o.optional = true;
        o.readonly = true;

        o = s.option(form.Value, 'update', _('Update At'));
        o.modalonly = false;
        o.optional = true;
        o.readonly = true;

        o = s.option(form.Button, 'update_subscription');
        o.editable = true;
        o.inputstyle = 'positive';
        o.inputtitle = _('Update');
        o.modalonly = false;
        o.onclick = function (_, section_id) {
            return nikki.updateSubscription(section_id);
        };

        o = s.option(form.Value, 'info_url', _('Subscription Info Url'));
        o.modalonly = true;

        o = s.option(form.Value, 'url', _('Subscription Url'));
        o.modalonly = true;
        o.rmempty = false;

        o = s.option(form.Value, 'user_agent', _('User Agent'));
        o.default = 'nikki-openwrt';
        o.modalonly = true;
        o.rmempty = false;
        o.value('clash');
        o.value('clash.meta');
        o.value('mihomo');
        o.value('nikki-openwrt');

        o = s.option(form.ListValue, 'hwid', _('HWID'));
        o.description = _('Send device identification headers with the subscription request. Required by panels which bind a subscription to a device.');
        o.default = '0';
        o.modalonly = true;
        o.rmempty = false;
        o.value('0', _('Disable'));
        o.value('1', _('Enable'));

        o = s.option(form.Value, 'hwid_value', _('Device ID') + ' (x-hwid)');
        o.description = _('Derived from the hardware of this router and kept across restarts.');
        o.placeholder = hwidDefaults.hwid_value;
        o.modalonly = true;
        o.retain = true;
        o.depends('hwid', '1');
        o.validate = function (section_id, value) {
            if (!value) {
                return true;
            }
            if (!/^[A-Za-z0-9._-]{1,64}$/.test(value)) {
                return _('Expected 1 to 64 characters: letters, digits, dot, hyphen or underscore');
            }
            return true;
        };

        o = s.option(form.Button, '_regenerate_hwid', _('Regenerate Device ID'));
        o.description = _('Issue a new random device id, for example after the subscription was reset by the provider.');
        o.inputstyle = 'apply';
        o.inputtitle = _('Regenerate');
        o.modalonly = true;
        o.retain = true;
        o.depends('hwid', '1');
        o.write = function () { };
        o.remove = function () { };
        o.onclick = function (ev, section_id) {
            const element = this.section.getUIElement(section_id, 'hwid_value');
            if (element) {
                element.setValue(randomHWID());
            }
            return Promise.resolve();
        };

        o = s.option(form.Value, 'hwid_device_os', _('Device OS') + ' (x-device-os)');
        o.placeholder = hwidDefaults.hwid_device_os;
        o.modalonly = true;
        o.retain = true;
        o.depends('hwid', '1');
        o.validate = headerValueValidator;

        o = s.option(form.Value, 'hwid_ver_os', _('OS Version') + ' (x-ver-os)');
        o.placeholder = hwidDefaults.hwid_ver_os;
        o.modalonly = true;
        o.retain = true;
        o.depends('hwid', '1');
        o.validate = headerValueValidator;

        o = s.option(form.Value, 'hwid_device_model', _('Device Model') + ' (x-device-model)');
        o.placeholder = hwidDefaults.hwid_device_model;
        o.modalonly = true;
        o.retain = true;
        o.depends('hwid', '1');
        o.validate = headerValueValidator;

        o = s.option(form.ListValue, 'prefer', _('Prefer'));
        o.default = 'remote';
        o.modalonly = true;
        o.rmempty = false;
        o.value('remote', _('Remote'));
        o.value('local', _('Local'));

        return m.render();
    }
});
