/**
 * Created by zeyad on 8/11/2022.
 */
// eslint-disable-next-line no-unused-expressions
({
  doInit: function (c, e, h) {
    const conditions = globalThis.structuredClone(c.get('v.initialCondition'));
    c.set('v.hovers', {});
    c.set('v.condition', globalThis.structuredClone(c.get('v.initialCondition')));
    if (conditions.contentVersions) {
      c.set('v.documentCount', conditions.contentVersions.length);
    }
    // Subquery comes through as either a plain array (modern API) or a
    // QueryResult wrapper { totalSize, done, records } (legacy shape).
    const ccRel = conditions.data.Condition_Comments__r;
    const unreadCount = !ccRel
      ? 0
      : Array.isArray(ccRel)
      ? ccRel.length
      : ccRel.records
      ? ccRel.records.length
      : 0;
    if (unreadCount > 0) {
      c.set('v.unreadCommentsCount', unreadCount);
    }
    c.set('v.condition.isSelected', false);
    c.set('v.cells', h.buildCells(c.get('v.columns'), conditions.data));
  },
  handleRowSelect: function (c) {
    const evt = c.getEvent('conditionRowEvent');
    evt.setParams({
      action: 'selectionChange',
      data: {
        conditionId: c.get('v.condition.data.Id'),
        isSelected: c.get('v.initialCondition.isSelected')
      }
    });
    evt.fire();
  },
  toggleOn: function (c, e) {
    c.set(e.currentTarget.dataset.identifier, true);
  },
  toggleDynamic: function (c, e) {
    const fieldApi = e.currentTarget.dataset.identifier;
    const cells = c.get('v.cells');
    const cell = cells.find(function (cel) {
      return cel.name === fieldApi;
    });
    if (!cell || !cell.isEditable) return;

    const hovers = c.get('v.hovers');
    for (const [key] of Object.entries(hovers)) {
      hovers[key].isEdit = false;
      hovers[key].previewEdit = false;
    }
    c.set('v.hovers', hovers);
    c.set('v.currentEditField', fieldApi);
    c.set('v.isFieldEdit', true);
  },
  deleteItem: function (c, e, h) {
    c.set('v.showSpinner', true);
    const deleteAction = c.get('c.deleteCondition');
    deleteAction.setParams({
      recordId: c.get('v.condition.data.Id')
    });
    deleteAction.setCallback(this, function (res) {
      c.set('v.showSpinner', false);
      if (res.getState() === 'SUCCESS') {
        const appEvent = $A.get('e.c:RefreshEvent');
        appEvent.fire();
      } else if (res.getState() === 'ERROR') {
        h.handleError(c, 'Failed to delete condition', res.getError());
      }
    });
    $A.enqueueAction(deleteAction);
  },
  cancelSave: function (c) {
    c.set('v.condition', globalThis.structuredClone(c.get('v.initialCondition')));
    const hovers = c.get('v.hovers');
    for (const [key] of Object.entries(hovers)) {
      hovers[key].isEdit = false;
      hovers[key].previewEdit = false;
    }
    c.set('v.hovers', hovers);
    c.set('v.isFieldEdit', false);
    c.set('v.currentEditField', '');
  },
  cancelSaveNotes: function (c) {
    c.set('v.condition', globalThis.structuredClone(c.get('v.initialCondition')));
    c.set('v.isExpandedNotes', false);
  },
  toggleIncludeInEmail: function (component, event, helper) {
    helper.toggleIncludeInEmailHelper(component);
  },
  toggleCanSee: function (component, event, helper) {
    helper.toggleCanSeeHelper(component);
  },
  saveFieldValue: function (c, e, h) {
    const hovers = c.get('v.hovers');
    const isEdit = Object.keys(hovers)
      .map((x) => hovers[x].isEdit && hovers[x].doesEditRestrictSave)
      .filter((x) => x === true).length;
    if (!isEdit) {
      const fieldName = e.getSource().get('v.fieldName');
      const value = e.getSource().get('v.value');
      for (const [key] of Object.entries(hovers)) {
        hovers[key].isEdit = false;
      }
      const condition = c.get('v.condition');
      condition.data[fieldName] = value;
    }
  },
  saveNotesRow: function (c, e, h) {
    const condition = c.get('v.condition');
    const action = c.get('c.saveCondition');
    c.set('v.showSpinner', true);
    action.setParams({
      condition: condition.data
    });
    action.setCallback(this, function (res) {
      c.set('v.showSpinner', false);
      if (res.getState() === 'SUCCESS') {
        c.set('v.initialCondition', globalThis.structuredClone(res.getReturnValue()));
        c.set('v.isExpandedNotes', true);
        c.set('v.hovers.uwnotes.isEdit', false);
        c.set('v.hovers.uwmdescription.isEdit', false);
      } else if (res.getState() === 'ERROR') {
        h.handleError(c, 'Failed to save notes', res.getError());
      }
    });
    $A.enqueueAction(action);
  },
  saveRow: function (c, e, h) {
    const condition = c.get('v.condition');
    const action = c.get('c.saveCondition');
    c.set('v.showSpinner', true);
    action.setParams({
      condition: condition.data
    });
    action.setCallback(this, function (res) {
      c.set('v.showSpinner', false);
      if (res.getState() === 'SUCCESS') {
        c.set('v.initialCondition', globalThis.structuredClone(res.getReturnValue()));
        c.set('v.condition', globalThis.structuredClone(res.getReturnValue()));
        $A.enqueueAction(c.get('c.doInit'));
        const appEvent = $A.get('e.c:ConditionsInit');
        appEvent.setParams({
          condition: res.getReturnValue()
        });
        appEvent.fire();
        c.set('v.isFieldEdit', false);
        c.set('v.currentEditField', '');
      } else if (res.getState() === 'ERROR') {
        h.handleError(c, 'Failed to save condition', res.getError());
      }
    });
    $A.enqueueAction(action);
  },
  toggleRead: function (c) {
    const condition = c.get('v.condition');
    const action = c.get('c.refreshCondition');
    action.setParams({
      condition: condition.data
    });
    action.setCallback(this, function (res) {
      const refreshedCondition = res.getReturnValue();
      c.set('v.initialCondition', refreshedCondition);
      const refreshedRel = refreshedCondition.data.Condition_Comments__r;
      const refreshedUnreadCount = !refreshedRel
        ? 0
        : Array.isArray(refreshedRel)
        ? refreshedRel.length
        : refreshedRel.records
        ? refreshedRel.records.length
        : 0;
      c.set('v.unreadCommentsCount', refreshedUnreadCount > 0 ? refreshedUnreadCount : null);
    });
    $A.enqueueAction(action);
  },
  reviewDocuments: function (c) {
    let modalBody;
    $A.createComponent(
      'c:ConditionsDocumentViewer',
      {
        applicationId: c.get('v.applicationId'),
        files: c.get('v.condition.contentVersions'),
        conditionId: c.get('v.condition.data.Id'),
        conditionName: c.get('v.condition.data.Name'),
        conditionDescription: c.get('v.condition.data.Description__c')
      },
      function (content, status) {
        if (status === 'SUCCESS') {
          modalBody = content;
          c.find('overlayLib').showCustomModal({
            header: 'Review Documents for ' + c.get('v.condition.data.Name'),
            body: modalBody,
            showCloseButton: true,
            cssClass: 'mymodal',
            closeCallback: function () {}
          });
        }
      }
    );
  },
  handleUploadFinished: function (component, event, helper) {
    const conditionId = component.get('v.condition.data.Id');
    const uploadedFiles = event.getParam('files');
    const contentVersionIds = [];
    for (const element of uploadedFiles) {
      contentVersionIds.push(element.contentVersionId);
    }
    const action = component.get('c.contentVersionUpdate');
    const params = {
      conditionId: conditionId,
      contentVersionIds: contentVersionIds
    };
    action.setParams(params);
    action.setCallback(this, function (response) {
      const state = response.getState();
      if (state === 'SUCCESS') {
        const appEvent = $A.get('e.c:RefreshEvent');
        appEvent.fire();
      } else if (state === 'ERROR') {
        helper.handleError(component, 'Failed to update content versions', response.getError());
      }
    });
    $A.enqueueAction(action);
  },
  enableNotes: function (c) {
    c.set('v.isExpandedNotes', !c.get('v.isExpandedNotes'));
  },
  enableComments: function (c) {
    c.set('v.isExpandedComments', !c.get('v.isExpandedComments'));
  },
  closeErrorNotification: function (c) {
    c.set('v.showErrorNotification', false);
  },
  closeSuccessNotification: function (c) {
    c.set('v.showSuccessNotification', false);
  }
});