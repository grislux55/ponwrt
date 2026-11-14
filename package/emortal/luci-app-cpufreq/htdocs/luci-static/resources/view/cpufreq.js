/* SPDX-License-Identifier: GPL-3.0-only
 *
 * Copyright (C) 2022 ImmortalWrt.org
 */

'use strict';
'require form';
'require fs';
'require uci';
'require view';

function formatFreq(freq) {
	const khz = parseInt(freq, 10);
	if (Number.isNaN(khz) || khz <= 0)
		return String(freq);
	if (khz >= 1000) {
		const mhz = khz / 1000;
		return Number.isInteger(mhz)
			? '%d MHz'.format(mhz)
			: '%.1f MHz'.format(mhz);
	}
	return '%d kHz'.format(khz);
}

function governorLabel(gov) {
	switch (gov) {
	case 'schedutil':
		return _('schedutil (Load-guided dynamic scaling)');
	case 'ondemand':
		return _('ondemand (Threshold-triggered scaling)');
	case 'conservative':
		return _('conservative (Stepwise dynamic scaling)');
	case 'performance':
		return _('performance (Lock target frequency)');
	case 'powersave':
		return _('powersave (Lock power-saving frequency)');
	case 'userspace':
		return _('userspace (Fixed manual frequency)');
	default:
		return gov;
	}
}

return view.extend({
	load() {
		return Promise.all([
			uci.load('cpufreq'),
			L.resolveDefault(fs.exec_direct('/etc/init.d/cpufreq', [ 'get_policies' ], 'json'), {})
		]);
	},

	render(data) {
		let m, s, o;

		m = new form.Map('cpufreq', _('CPU Freq Settings'),
			_('Configure CPU scaling governor and operating frequencies.'));

		s = m.section(form.NamedSection, 'cpufreq', 'settings');

		if (Object.keys(data[1]).length === 0) {
			s.render = () => {
				this.handleSaveApply = null;
				this.handleSave = null;
				this.handleReset = null;

				return E('div', { 'class': 'cbi-section warning' }, [
					E('h3', {}, _('Unsupported device!')),
					E('p', {}, _('Your device/kernel does not support CPU frequency scaling.'))
				]);
			};
		} else {
			let ss = m.section(form.NamedSection, 'global', 'settings');
			let so = ss.option(form.HiddenValue, 'set');
			so.load = () => 1;
			so.readonly = true;
			so.rmempty = false;

			for (let i in data[1]) {
				const index = data[1][i].index;
				const rawFreqs = Array.isArray(data[1][i].freqs) ? data[1][i].freqs : [];
				const freqs = rawFreqs.slice().sort((a, b) => parseInt(a, 10) - parseInt(b, 10));
				const governors = Array.isArray(data[1][i].governors) ? data[1][i].governors : [];
				if (freqs.length === 0 || governors.length === 0)
					continue;

				const lowestFreq = freqs[0];
				const highestFreq = freqs[freqs.length - 1];
				const fixedTargetGovs = governors.filter(g => g === 'performance' || g === 'userspace');
				const hasPowersave = governors.includes('powersave');
				const dynamicGovs = governors.filter(g => g !== 'performance' && g !== 'userspace' && g !== 'powersave');

				s.tab(index, i, _('<h4>Apply for CPU %s.</h4>').format(data[1][i].cpus));

				o = s.taboption(index, form.ListValue, 'governor' + index, _('CPU Scaling Governor'));
				for (const gov of governors)
					o.value(gov, governorLabel(gov));
				o.rmempty = false;

				if (dynamicGovs.length > 0) {
					o = s.taboption(index, form.ListValue, 'minfreq' + index, _('Minimum Idle Frequency'),
						_('Lower frequency bound during idle or light load.'));
					for (const freq of freqs)
						o.value(freq, formatFreq(freq));
					for (const gov of dynamicGovs)
						o.depends('governor' + index, gov);
					o.default = lowestFreq;
					o.rmempty = false;
					o.retain = true;
					o.forcewrite = true;
					o.remove = function() {};

					o = s.taboption(index, form.ListValue, 'maxfreq' + index, _('Maximum Scaling Frequency'),
						_('Upper frequency bound under load.'));
					for (const freq of freqs)
						o.value(freq, formatFreq(freq));
					for (const gov of dynamicGovs)
						o.depends('governor' + index, gov);
					o.default = highestFreq;
					o.rmempty = false;
					o.retain = true;
					o.forcewrite = true;
					o.remove = function() {};
					o.validate = function(section_id, value) {
						if (!section_id)
							return true;
						if (value === null || value === '')
							return _('Expecting: %s').format('non-empty value');

						const minOpt = this.map.lookupOption('minfreq' + index, section_id);
						const minfreq = minOpt && minOpt[0] ? minOpt[0].formvalue(section_id) : null;
						if (minfreq && parseInt(value, 10) < parseInt(minfreq, 10))
							return _('Max CPU Freq cannot be lower than Min CPU Freq.');

						return true;
					};
				}

				if (fixedTargetGovs.length > 0) {
					o = s.taboption(index, form.ListValue, '_targetfreq' + index, _('Locked CPU Frequency'),
						_('CPU stays at the selected frequency in this mode.'));
					for (const freq of freqs)
						o.value(freq, formatFreq(freq));
					for (const gov of fixedTargetGovs)
						o.depends('governor' + index, gov);
					o.default = highestFreq;
					o.rmempty = false;
					o.retain = true;
					o.forcewrite = true;
					o.remove = function() {};
					o.cfgvalue = function(section_id) {
						return uci.get('cpufreq', section_id, 'maxfreq' + index) || highestFreq;
					};
					o.write = function(section_id, formvalue) {
						uci.set('cpufreq', section_id, 'maxfreq' + index, formvalue);
						const curMin = uci.get('cpufreq', section_id, 'minfreq' + index);
						if (!curMin)
							uci.set('cpufreq', section_id, 'minfreq' + index, lowestFreq);
						else if (parseInt(curMin, 10) > parseInt(formvalue, 10))
							uci.set('cpufreq', section_id, 'minfreq' + index, formvalue);
					};
				}

				if (hasPowersave) {
					o = s.taboption(index, form.ListValue, '_savefreq' + index, _('Power-Saving CPU Frequency'),
						_('CPU stays at the selected power-saving frequency.'));
					for (const freq of freqs)
						o.value(freq, formatFreq(freq));
					o.depends('governor' + index, 'powersave');
					o.default = lowestFreq;
					o.rmempty = false;
					o.retain = true;
					o.forcewrite = true;
					o.remove = function() {};
					o.cfgvalue = function(section_id) {
						return uci.get('cpufreq', section_id, 'minfreq' + index) || lowestFreq;
					};
					o.write = function(section_id, formvalue) {
						uci.set('cpufreq', section_id, 'minfreq' + index, formvalue);
						const curMax = uci.get('cpufreq', section_id, 'maxfreq' + index);
						if (!curMax)
							uci.set('cpufreq', section_id, 'maxfreq' + index, highestFreq);
						else if (parseInt(curMax, 10) < parseInt(formvalue, 10))
							uci.set('cpufreq', section_id, 'maxfreq' + index, formvalue);
					};
				}

				o = s.taboption(index, form.Value, 'sdfactor' + index, _('CPU Switching Sampling rate'),
					_('The sampling rate determines how frequently the governor checks to tune the CPU (ms)'));
				o.datatype = 'range(1,100000)';
				o.default = '10';
				o.depends('governor' + index, 'ondemand');
				o.rmempty = false;
				o.retain = true;
				o.remove = function() {};

				o = s.taboption(index, form.Value, 'upthreshold' + index, _('CPU Switching Threshold'),
					_('Kernel make a decision on whether it should increase the frequency (%)'));
				o.datatype = 'range(1,99)';
				o.default = '50';
				o.depends('governor' + index, 'ondemand');
				o.rmempty = false;
				o.retain = true;
				o.remove = function() {};
			}
		}

		return m.render();
	}
});
