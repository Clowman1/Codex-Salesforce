/**
 * Created by zeyad on 8/17/2022.
 */

// eslint-disable-next-line no-unused-expressions
({
  saveFieldValue: function (c, recordId, fieldName, value, hovers) {
    c.set('v.showSpinner', true);
    const action = c.get('c.fieldValueSave');
    action.setParams({
      recordId: recordId,
      fieldName: fieldName,
      value: value
    });
    action.setCallback(this, function (res) {
      if (res.getState() === 'SUCCESS') {
        c.set('v.showSpinner', false);
        c.set('v.hovers', hovers);
        c.set('v.initialCondition', globalThis.structuredClone(res.getReturnValue()));
        $A.enqueueAction(c.get('c.doInit'));
        const appEvent = $A.get('e.c:ConditionsInit');
        appEvent.setParams({
          condition: res.getReturnValue()
        });
        appEvent.fire();
      } else if (res.getState() === 'ERROR') {
        c.set('v.showSpinner', false);
        this.handleError(c, 'Failed to save field value', res.getError());
      }
    });
    $A.enqueueAction(action);
  },
  toggleIncludeInEmailHelper: function (component) {
    try {
      const hovers = component.get('v.hovers');
      if (
        !Object.keys(hovers)
          .map((x) => hovers[x].isEdit && hovers[x].doesEditRestrictSave)
          .filter((x) => x === true).length
      ) {
        component.set('v.condition.data.Include_In_Email__c', !component.get('v.condition.data.Include_In_Email__c'));
        this.saveFieldValue(
          component,
          component.get('v.condition.data.Id'),
          'Include_In_Email__c',
          component.get('v.condition.data.Include_In_Email__c'),
          hovers
        );
        if (component.get('v.condition.data.Include_In_Email__c')) {
          this.saveFieldValue(component, component.get('v.condition.data.Id'), 'Can_Borrower_See__c', true, hovers);
        }
      }
    } catch (e) {
      this.handleError(component, 'Failed to toggle include in email', e);
    }
  },
  toggleCanSeeHelper: function (component) {
    try {
      const hovers = component.get('v.hovers');
      component.set('v.condition.data.Can_Borrower_See__c', !component.get('v.condition.data.Can_Borrower_See__c'));
      if (
        !Object.keys(hovers)
          .map((x) => hovers[x].isEdit && hovers[x].doesEditRestrictSave)
          .filter((x) => x === true).length
      ) {
        this.saveFieldValue(
          component,
          component.get('v.condition.data.Id'),
          'Can_Borrower_See__c',
          component.get('v.condition.data.Can_Borrower_See__c'),
          hovers
        );
      }
    } catch (e) {
      this.handleError(component, 'Failed to toggle can borrower see', e);
    }
  },
  buildCells: function (columns, record) {
    if (!columns || !record) {
      return [];
    }
    return columns.map((col) => {
      const cell = {
        name: col.name,
        label: col.label,
        type: (col.type || '').toUpperCase(),
        isEditable: !!col.isEditable,
        isAction: col.name === 'Action',
        value: null,
        displayValue: null,
        hasAvatar: false,
        hasRelationship: false,
        photoUrl: null,
        initials: null
      };
      if (cell.isAction) {
        return cell;
      }

      cell.value = col.name.indexOf('.') > -1 ? this.getNestedValue(record, col.name) : record[col.name];
      this.resolveDisplay(cell, col, record);

      return cell;
    }, this);
  },
  resolveDisplay: function (cell, col, record) {
    if (cell.type !== 'REFERENCE') {
      cell.displayValue = cell.value;
      return;
    }

    const rel = this.getRelationship(record, col.name);
    if (!rel) {
      cell.displayValue = cell.value;
      return;
    }

    cell.hasRelationship = true;
    cell.displayValue = rel.Name || cell.value;

    if (!col.isUserLookup) {
      return;
    }

    cell.hasAvatar = true;
    cell.photoUrl = rel.MediumPhotoUrl || null;
    cell.initials = rel.Name ? this.resolveInitials(rel.Name) : null;
  },
  resolveInitials: function (name) {
    const parts = name.split(' ').filter(Boolean);
    if (parts.length > 1) {
      return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  },
  getNestedValue: function (obj, path) {
    if (!obj || !path) {
      return undefined;
    }
    const parts = path.split('.');
    let current = obj;
    for (let i = 0; i < parts.length; i++) {
      if (current == null) {
        return undefined;
      }
      current = current[parts[i]];
    }
    return current;
  },
  getRelationship: function (record, fieldName) {
    if (fieldName.endsWith('__c')) {
      return record[fieldName.replace(/__c$/, '__r')] || null;
    }
    if (fieldName.endsWith('Id')) {
      return record[fieldName.slice(0, -2)] || null;
    }
    return null;
  },
  handleError: function (c, context, error) {
    globalThis.plog.error('ConditionRow', { message: context, error });
    const extracted = Array.isArray(error) ? error[0] : error;
    const message = (extracted && extracted.message) || extracted;
    c.set('v.errorMessage', context + ': ' + message);
    c.set('v.showErrorNotification', true);
  }
});