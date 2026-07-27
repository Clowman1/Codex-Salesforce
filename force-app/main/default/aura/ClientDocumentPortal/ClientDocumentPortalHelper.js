({
	groupBy : function(array, keyFn) {
		return array.reduce((result, item) => {
			const key = keyFn(item);
			result[key] = result[key] || [];
			result[key].push(item);
			return result;
		}, {});
	},
	successHandler : function(component, response) {
		let decryptedRecordId;
		let data = response.getReturnValue();
		decryptedRecordId = data.recordId;
		if (data.conditions && data.conditions.length > 0) {
			data.conditionSections = [];

			let objectWithGroupedStatuses = this.groupBy(
				data.conditions,
				({ status }) => status
			);

			const filters = this.parseConditionsFilter(component);
			if (filters) {
				for (const [key, value] of Object.entries(objectWithGroupedStatuses)) {
					const filter = filters.find(elem => elem.status === key);
					if (filter) {
						data.conditionSections.push({
							name: key,
							conditions: value,
							filter
						});
					}
				}
				data.conditionSections.sort((a, b) => a.filter.order - b.filter.order);
			} else {
				this.showToast('Please set the condition filters', 'warning', 'Error');
			}
		}

		component.set('v.recordId', decryptedRecordId);
		component.set('v.data', response.getReturnValue());
	},
	errorHandler : function(component, response) {
		const errors = response.getError();
		if (errors) {
			if (errors.length && errors[0].message) {
				alert(JSON.stringify(errors));
				console.log("Error message: " + errors[0].message);
				console.log("Error message: ", errors[0]);
			}
		} else {
			console.log("Unknown error");
		}
		component.set('v.state', state);
	},
	getData: function(component) {
		try {
			this.setLayering(component);
			const isInSitePreview = () =>
				["sitepreview", "livepreview", "live-preview", "live.", ".builder."].some(
					(substring) => document.URL.includes(substring)
				);
			let recordId = this.getJsonFromUrl().id;
			component.set('v.hashId', recordId);
			const action = component.get('c.initializeData');
			action.setParams({hashFromURL : recordId,isInSitePreview : isInSitePreview()});
			action.setCallback(this, function(response){
				const state = response.getState();
				if (state === "SUCCESS") {
					this.successHandler(component, response);
				} else if (state === "ERROR") {
					this.errorHandler(component, response);
				}
			});
			$A.enqueueAction(action);
		} catch(e) {
			console.log('error getting data in Client Document Portal component', e.message);
		}
	},
	setLayering :function(component) {
		const backgroundUrl = component.get('v.yourTeamBackroundImageUrl');
		if (!backgroundUrl) {
			const yourTeamBackgroundUrl = $A.get('$Resource.PULSEResources') + '/img/Your-Team-Background.png';
			component.set('v.yourTeamBackroundImageUrl', yourTeamBackgroundUrl);
		}

		const brandColor = component.get('v.brandColor');
		const transparentBrandColor =  brandColor.replace(')', ', 0.9)').replace('rgb', 'rgba');
		component.set('v.transparentBrandColor', transparentBrandColor);
	},

	getJsonFromUrl : function () {
		const query = location.search.substring(1);
		const result = {};
		query.split("&").forEach(function(part) {
			const item = part.split("=");
			result[item[0]] = decodeURIComponent(item[1]);
		});
		return result;
	},
	parseConditionsFilter: function(component) {
		try {
			let filters = component.get('v.conditionFiltersByStatus');
			if (filters) {
				return JSON.parse(filters);
			}
		} catch (e) {
			console.log('error in parsing conditions filter in Client Document Portal component', e);
		}
		return null;
	},
	showToast: function (message, type, title) {
		const toastEvent = $A.get('e.force:showToast');
		toastEvent.setParams({
			title: title,
			mode: 'dismissible',
			message: message,
			type: type
		});
		toastEvent.fire();
	}
});