/**
 * Created by zeyad on 8/11/2022.
 */

// eslint-disable-next-line no-unused-expressions
({
  doInit: function (c, e, h) {
    h.loadFieldDescriptionsAndData(c);
  },
  onTabRefreshed: function (component, event, helper) {
    helper.setData(component);
  },
  onRender: function (c, e, h) {
    h.setStyleVariables(c);
  },
  reInit: function (c, e, h) {
    h.updateData(c, e);
  },
  filterOwner: function (c, e, h) {
    h.filterConditionsByOwner(c, e);
  },
  flowStatusChange: function (c, e, h) {
    h.flowStatusChangeHelper(c, e);
  },
  handleCancel: function (c, e, h) {
    h.cancelFlow(c);
  },
  openEmailModal: function (c, e, h) {
    h.openConditionsEmailHelper(c);
  },
  createConditions: function (c, e, h) {
    h.createConditionsHelper(c);
  },
  updateConditions: function (c, e, h) {
    h.updateConditionsHelper(c);
  },
  handleDownload: function (c, e, h) {
    h.handleDownloadHelper(c);
  },
  handleSelectAll: function (c, e, h) {
    h.handleSelectAllHelper(c, e);
  },
  closeErrorNotification: function (c) {
    c.set('v.showErrorNotification', false);
  },
  closeWarningNotification: function (c) {
    c.set('v.showWarningNotification', false);
  },
  handleConditionRowEvent: function (c, e, h) {
    h.handleConditionRowEventHelper(c, e);
  },
  closeInfoNotification: function (c) {
    c.set('v.conditionsTypeNotSet', false);
  }
});