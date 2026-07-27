({
  CONDITION_TABLE_LABELS: {
    OUTSTANDING: 'Outstanding Conditions',
    READY_FOR_LENDER: 'Ready for Lender Conditions',
    CLEARED: 'Cleared Conditions'
  },
  CONDITION_STATUSES: {
    NEW: 'New',
    REQUESTED: 'Requested',
    REVIEW: 'Review',
    CLEARED: 'Cleared',
    APPROVED: 'Approved'
  },
  // Default column widths by Salesforce DisplayType.
  // https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_Schema_DisplayType.htm
  COLUMN_WIDTH_BY_TYPE: {
    BOOLEAN: '90px',
    INTEGER: '100px',
    PERCENT: '90px',
    CURRENCY: '100px',
    DOUBLE: '100px',
    STRING: '110px',
    ID: '100px',
    DATE: '120px',
    COMBOBOX: '120px',
    DATETIME: '170px',
    PHONE: '120px',
    PICKLIST: '150px',
    MULTIPICKLIST: '120px',
    REFERENCE: '180px',
    EMAIL: '130px',
    ENCRYPTEDSTRING: '150px',
    TEXTAREA: '180px',
    URL: '150px'
  },
  CHECKBOX_WIDTH: 40,
  ACTION_WIDTH: 320,
  getColumnWidth: function (displayType) {
    return this.COLUMN_WIDTH_BY_TYPE[(displayType || '').toUpperCase()] || '100px';
  },
  // Default condition tables. Used to set component variable conditionTables.
  // Labels, rows, order and other properties will be set from filters if they exist.
  // Rows will be filtered by status
  conditionTables: [
    {
      label: 'Outstanding Conditions',
      columns: [],
      rows: [],
      size: 0,
      order: 0,
      new: 0,
      requested: 0,
      review: 0
    },
    {
      label: 'Ready for Lender Conditions',
      columns: [],
      rows: [],
      size: 0,
      order: 1
    },
    {
      label: 'Cleared Conditions',
      columns: [],
      rows: [],
      size: 0,
      order: 2
    }
  ],
  loadFieldDescriptionsAndData: function (c) {
    const columnsToShow = c.get('v.columnsToShow') || 'Name,Status__c,CreatedDate,Requested_Date__c,ETA__c,Assigned_To__c';
    const fieldApiNames = columnsToShow
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    if (!fieldApiNames.some((n) => n.toLowerCase() === 'name')) {
      fieldApiNames.unshift('Name');
    }

    const action = c.get('c.getConditionFieldDescriptions');
    action.setParams({ fieldApiNames });
    action.setCallback(this, function (res) {
      if (res.getState() === 'SUCCESS') {
        c.set('v.conditionFieldDescriptions', res.getReturnValue() || []);
        globalThis.plog.info('ConditionsViewer', { message: 'Condition field descriptions loaded successfully', data: globalThis.structuredClone(res.getReturnValue()) });
      } else {
        c.set('v.conditionFieldDescriptions', []);
      }
      this.setData(c);
    });
    $A.enqueueAction(action);
  },
  setData: function (c) {
    try {
      const conditionsType = c.get('v.conditionsType');
      const conditionsTypes = c.get('v.conditionsTypes');

      if (!conditionsType && !conditionsTypes) {
        c.set('v.conditionsTypeNotSet', true);
        return;
      }

      c.set('v.conditionsTypeNotSet', false);
      c.set('v.spinner', true);
      const fieldDescriptions = c.get('v.conditionFieldDescriptions') || [];
      const columnFields = fieldDescriptions.map(function (f) {
        return f.apiName;
      });
      const action = c.get('c.getConditionsByType');
      action.setParams({
        loanId: c.get('v.recordId'),
        type: conditionsTypes || conditionsType,
        columnFields: columnFields
      });
      action.setCallback(this, function (res) {
        if (res.getState() === 'SUCCESS') {
          const conditionsFilteredByStatus = this.filterConditionsByStatus(c, res.getReturnValue().conditions);

          let conditions = [];
          if (conditionsFilteredByStatus.length > 0) {
            conditions = conditionsFilteredByStatus;
          } else {
            conditions = res.getReturnValue().conditions;
          }

          let uniqueOwners = this.getUniqueOwnersFromConditions(conditions, null);
          this.generateTables(c, conditions);
          this.sortConditionsByOrder(c);

          c.set('v.conditionTables', c.get('v.conditionTables'));
          c.set('v.initialConditions', conditions);
          c.set('v.uniqueOwners', uniqueOwners);
          c.set('v.application', res.getReturnValue().application);
          c.set('v.spinner', false);
        } else if (res.getState() === 'ERROR') {
          this.handleError(c, 'Failed to load conditions', res.getError());
          c.set('v.spinner', false);
        }
      });
      $A.enqueueAction(action);
    } catch (e) {
      this.handleError(c, 'Failed to initialize conditions data', e);
    }
  },
  MOBILE_BREAKPOINT_PX: 768,
  setStyleVariables: function (component) {
    try {
      const wrapper = component.find('conditions-viewer__wrapper').getElement();
      if (!wrapper) {
        return;
      }
      const brandColor = component.get('v.brandColor');
      if (brandColor) {
        wrapper.style.setProperty('--brandColor', brandColor);
      }
      const fieldDescriptions = Array.from(component.get('v.conditionFieldDescriptions') || []);
      const gridParts = [this.CHECKBOX_WIDTH + 'px'];
      let minWidth = this.CHECKBOX_WIDTH + this.ACTION_WIDTH;

      fieldDescriptions.forEach((field, i) => {
        const width = this.getColumnWidth(field.type);
        wrapper.style.setProperty('--col-' + i, width);
        gridParts.push('minmax(var(--col-' + i + ', ' + width + '), 1fr)');
        minWidth += Number.parseInt(width, 10);
      });

      gridParts.push(this.ACTION_WIDTH + 'px');
      wrapper.style.setProperty('--table-grid-columns', gridParts.join(' '));
      wrapper.style.setProperty('--table-min-width', minWidth + 'px');

      this.initResizeObserver(component, wrapper);
    } catch (e) {
      this.handleError(component, 'Failed to set style variables', e);
    }
  },
  initResizeObserver: function (component, wrapper) {
    if (component.get('v.resizeObserver')) {
      return;
    }
    try {
      const breakpoint = this.MOBILE_BREAKPOINT_PX;
      const observer = new ResizeObserver(function (entries) {
        const width = entries[0].contentRect.width;
        component.set('v.isMobileView', width <= breakpoint);
        wrapper.style.setProperty('--container-width', width + 'px');
      });
      observer.observe(wrapper);
      component.set('v.resizeObserver', observer);
    } catch (e) {
      globalThis.plog.error('ConditionsViewer', { message: 'Failed to initialize ResizeObserver', error: e });
    }
  },
  getAllowedTypes: function (component) {
    const typeFilter = component.get('v.conditionsTypes') || component.get('v.conditionsType') || '';
    return typeFilter
      .split(/[,;]/)
      .map(function (t) {
        return t.trim();
      })
      .filter(Boolean);
  },
  updateData: function (component, e) {
    try {
      let updatedCondition = globalThis.structuredClone(e.getParam('condition'));
      const conditionTables = component.get('v.conditionTables');
      const uniqueOwners = component.get('v.uniqueOwners');
      let initialConditions = component.get('v.initialConditions');

      conditionTables.forEach((table) => {
        if (table.rows.some((condition) => condition.data.Id === updatedCondition.data.Id)) {
          const changedCondition = table.rows.find((condition) => condition.data.Id === updatedCondition.data.Id);
          changedCondition.data = updatedCondition.data;
          this.getUniqueOwnersFromConditions([changedCondition], uniqueOwners);
        }
      });

      initialConditions.forEach((condition) => {
        if (condition.data.Id === updatedCondition.data.Id) {
          condition.data = updatedCondition.data;
        }
      });

      // Remove conditions whose type no longer matches this viewer's filter
      const allowedTypes = this.getAllowedTypes(component);
      if (allowedTypes.length > 0) {
        initialConditions = initialConditions.filter(function (condition) {
          return allowedTypes.indexOf(condition.data.Type__c) > -1;
        });
      }

      const conditionsFilteredByStatus = this.filterConditionsByStatus(component, initialConditions);
      this.generateTables(component, conditionsFilteredByStatus);
      this.sortConditionsByOrder(component);

      component.set('v.conditionTables', component.get('v.conditionTables'));
      component.set('v.uniqueOwners', uniqueOwners);
      component.set('v.initialConditions', conditionsFilteredByStatus);
    } catch (e) {
      this.handleError(component, 'Failed to update condition data', e);
    }
  },
  updateConditionsHelper: function (component) {
    try {
      component.set('v.showFlow', true);
      const flow = component.find('updateConditionsFlow');
      const conditionTables = component.get('v.conditionTables');

      const outstandingConditions = conditionTables.filter((table) =>
        table.rows.every((condition) => condition.data.Status__c !== this.CONDITION_STATUSES.CLEARED)
      );

      if (!flow || !outstandingConditions) {
        return;
      } else {
        if (outstandingConditions[0].rows.length === 0 && outstandingConditions[1].rows.length === 0) {
          return;
        }
      }

      const conditionsToDo = [];

      outstandingConditions.forEach((table) => {
        table.rows.forEach((condition) => {
          if (condition.isSelected) {
            let cond = {
              Id: condition.data.Id,
              Name: condition.data.Name,
              Description__c: condition.data.Description__c,
              Assigned_To__c: condition.data.Assigned_To__c,
              Status__c: condition.data.Status__c,
              ETA__c: condition.data.ETA__c,
              Include_In_Email__c: condition.data.Include_In_Email__c,
              Can_Borrower_See__c: condition.data.Can_Borrower_See__c
            };
            conditionsToDo.push(cond);
          }
        });
      });

      const inputVariables = [
        {
          name: 'ConditionsToUpdate',
          type: 'SObject',
          value: conditionsToDo
        }
      ];
      flow.startFlow(component.get('v.updateConditionsFlowAPIName'), inputVariables);
    } catch (e) {
      this.handleError(component, 'Failed to mass update conditions', e);
    }
  },
  generateTables: function (c, conditions) {
    try {
      if (!conditions || conditions.length === 0) {
        this.clearConditionTables(c);
        return;
      }
      // Build columns header and visibility from the design attribute
      const columns = this.buildColumns(c);

      c.set('v.conditionTables', []);
      const conditionTables = c.get('v.conditionTables');

      let filters = c.get('v.conditionFiltersByStatus');
      if (filters) {
        filters = JSON.parse(filters);
        filters.forEach((filter) => {
          const tableObject = {
            label: filter.label,
            rows: [],
            size: 0,
            order: filter.order,
            columns: columns
          };
          if (Object.hasOwn(filter, 'statuses')) {
            const filteredConditions = filter.statuses.reduce((acc, status) => {
              conditions.filter((condition) => condition.data.Status__c === status).forEach((condition) => acc.push(condition));
              return acc;
            }, []);
            tableObject.rows = filteredConditions;
            tableObject.size = filteredConditions.length;
            tableObject.columns = columns;

            if (Object.hasOwn(filter, 'statuses')) {
              // only set outstanding tile numbers if there are new, requested, or review statuses
              this.setOutstandingTileNumbersToZero(filter.statuses, tableObject);
            }

            if (tableObject.rows.some((condition) => condition.data.Status__c === this.CONDITION_STATUSES.NEW)) {
              tableObject.new = tableObject.rows.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.NEW).length;
            }
            if (tableObject.rows.some((condition) => condition.data.Status__c === this.CONDITION_STATUSES.REQUESTED)) {
              tableObject.requested = tableObject.rows.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.REQUESTED).length;
            }
            if (tableObject.rows.some((condition) => condition.data.Status__c === this.CONDITION_STATUSES.REVIEW)) {
              tableObject.review = tableObject.rows.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.REVIEW).length;
            }
          }
          conditionTables.push(tableObject);
        });
      } else {
        this.conditionTables.forEach((table) => {
          const tableObject = {
            label: table.label,
            order: table.order
          };
          switch (table.label) {
            case this.CONDITION_TABLE_LABELS.OUTSTANDING: {
              const outstandingConditions = conditions.filter(
                (condition) =>
                  condition.data.Status__c !== this.CONDITION_STATUSES.CLEARED &&
                  condition.data.Status__c !== this.CONDITION_STATUSES.APPROVED
              );
              tableObject.rows = outstandingConditions;
              tableObject.size = outstandingConditions.length;
              tableObject.new = conditions.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.NEW).length;
              tableObject.requested = conditions.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.REQUESTED).length;
              tableObject.review = conditions.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.REVIEW).length;
              tableObject.columns = columns;
              conditionTables.push(tableObject);
              break;
            }
            case this.CONDITION_TABLE_LABELS.CLEARED: {
              const clearedConditions = conditions.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.CLEARED);
              tableObject.rows = clearedConditions;
              tableObject.size = clearedConditions.length;
              tableObject.columns = columns;
              conditionTables.push(tableObject);
              break;
            }
            case this.CONDITION_TABLE_LABELS.READY_FOR_LENDER: {
              const lenderConditions = conditions.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.APPROVED);
              tableObject.rows = lenderConditions;
              tableObject.size = lenderConditions.length;
              tableObject.columns = columns;
              conditionTables.push(tableObject);
              break;
            }
          }
        });
      }
    } catch (e) {
      this.handleError(c, 'Failed to generate condition tables', e);
    }
  },
  filterTables: function (component) {
    try {
      let conditions = component.get('v.initialConditions');
      if (component.get('v.filteredOwner')) {
        conditions = conditions.filter((condition) => condition.data.Assigned_To__c === component.get('v.filteredOwner'));
      }
      this.generateTables(component, conditions);
      this.sortConditionsByOrder(component);
      component.set('v.conditionTables', component.get('v.conditionTables'));
    } catch (e) {
      this.handleError(component, 'Failed to filter tables', e);
    }
  },
  filterConditionsByStatus: function (component, conditions) {
    let conditionsFilteredByStatus = [];
    try {
      let filters = component.get('v.conditionFiltersByStatus');

      if (!filters) {
        return conditions;
      }

      filters = JSON.parse(filters);

      conditionsFilteredByStatus = filters.reduce((acc, filter) => {
        conditions.filter((condition) => filter.statuses.includes(condition.data.Status__c)).forEach((condition) => acc.push(condition));
        return acc;
      }, []);
    } catch (e) {
      this.handleError(component, 'Failed to filter conditions by status', e);
    }
    return conditionsFilteredByStatus;
  },
  filterConditionsByOwner: function (component, event) {
    try {
      const target = event.target.closest('[data-owner-id]');
      const ownerId = target ? target.dataset.ownerId : null;
      if (!ownerId) {
        return;
      }
      if (component.get('v.filteredOwner') === ownerId) {
        component.set('v.filteredOwner', null);
      } else {
        component.set('v.filteredOwner', ownerId);
      }
      this.filterTables(component);
    } catch (e) {
      this.handleError(component, 'Failed to filter conditions by owner', e);
    }
  },
  sortConditionsByOrder: function (component) {
    try {
      const conditionTables = component.get('v.conditionTables');
      let filters = component.get('v.conditionFiltersByStatus');
      if (!filters) {
        return;
      }
      filters = JSON.parse(filters);

      filters.forEach((filter) => {
        conditionTables.forEach((condition) => {
          if (filter.label === condition.label) {
            condition.order = filter.order;
          }
        });
      });

      this.sortArrayOfObjects(component, conditionTables, 'order');
    } catch (e) {
      this.handleError(component, 'Failed to sort conditions by order', e);
    }
  },
  clearConditionTables: function (component) {
    try {
      // Build dynamic columns for empty state as well
      const columns = this.buildColumns(component);
      component.set('v.conditionTables', []);
      const conditionTables = component.get('v.conditionTables');
      let filters = component.get('v.conditionFiltersByStatus');

      if (filters) {
        filters = JSON.parse(filters);
        filters.forEach((filter) => {
          const tableObject = {
            label: filter.label,
            rows: [],
            size: 0,
            order: filter.order,
            columns: columns
          };
          if (Object.hasOwn(filter, 'statuses')) {
            this.setOutstandingTileNumbersToZero(filter.statuses, tableObject);
          }
          conditionTables.push(tableObject);
        });
      } else {
        this.conditionTables.forEach((table) => {
          const tableObject = {
            label: table.label,
            order: table.order,
            rows: [],
            size: 0,
            columns: columns
          };
          if (Object.hasOwn(table, 'new')) {
            tableObject.new = 0;
          }
          if (Object.hasOwn(table, 'requested')) {
            tableObject.requested = 0;
          }
          if (Object.hasOwn(table, 'review')) {
            tableObject.review = 0;
          }
          conditionTables.push(tableObject);
        });
      }
    } catch (e) {
      this.handleError(component, 'Failed to clear condition tables', e);
    }
  },
  buildColumns: function (component) {
    const fieldDescriptions = Array.from(component.get('v.conditionFieldDescriptions') || []);
    const columns = fieldDescriptions.map((info) => ({
      name: info.apiName,
      label: info.label,
      type: info.type,
      isEditable: !!info.isEditable && info.apiName.indexOf('.') === -1,
      isUserLookup: !!info.isUserLookup,
      width: this.getColumnWidth(info.type),
      classy: info.isUserLookup ? 'slds-align_absolute-center' : ''
    }));
    columns.push({ name: 'Action', label: 'Action', width: this.ACTION_WIDTH + 'px', classy: 'slds-text-align_center' });
    return columns;
  },
  setOutstandingTileNumbersToZero: function (statuses, tableObject) {
    try {
      statuses.forEach((status) => {
        if (status.toLowerCase() === this.CONDITION_STATUSES.NEW.toLowerCase()) {
          tableObject.new = 0;
        }
        if (status.toLowerCase() === this.CONDITION_STATUSES.REQUESTED.toLowerCase()) {
          tableObject.requested = 0;
        }
        if (status.toLowerCase() === this.CONDITION_STATUSES.REVIEW.toLowerCase()) {
          tableObject.review = 0;
        }
      });
    } catch (e) {
      console.log('error in setting outstanding tile numbers to zero in Conditions Viewer component', e);
    }
  },
  getUniqueOwnersFromConditions: function (conditions, uniqueOwners) {
    try {
      if (!uniqueOwners) {
        uniqueOwners = [];
      }
      if (!conditions || conditions.length === 0) {
        return uniqueOwners;
      }

      conditions.forEach((condition) => {
        const hasOwnerAlreadyAdded = uniqueOwners.some((owner) => owner.id === condition.data.Assigned_To__c);
        if (!hasOwnerAlreadyAdded && condition.data.Assigned_To__c) {
          const ownerName = condition.data.Assigned_To__r.Name || '';
          const nameParts = ownerName.split(' ').filter(Boolean);
          const initials = nameParts.length > 1 ? nameParts[0].charAt(0) + nameParts[nameParts.length - 1].charAt(0) : ownerName.substring(0, 2);
          uniqueOwners.push({
            url: condition.data.Assigned_To__r.MediumPhotoUrl,
            name: ownerName,
            initials: initials.toUpperCase(),
            id: condition.data.Assigned_To__r.Id
          });
        }
      });
    } catch (e) {
      console.log('error in getting unique owners in Conditions Viewer component', e);
    }
    return uniqueOwners;
  },
  openConditionsEmailHelper: function (component) {
    try {
      const modalComponent = component.get('v.modalComponent');
      $A.createComponent(
        modalComponent,
        {
          recordId: component.get('v.recordId'),
          application: component.get('v.application'),
          conditionType: component.get('v.conditionsType'),
          emailTemplates: component.get('v.emailTemplates'),
          emailSendersClassAPIName: component.get('v.emailSendersClassAPIName')
        },
        function (content, status) {
          if (status === 'SUCCESS') {
            component.find('overlayLib').showCustomModal({
              header: 'Conditions Email',
              body: content,
              showCloseButton: true,
              cssClass: 'conditionsEmailModal',
              closeCallback: function () {}
            });
          }
        }
      );
    } catch (e) {
      this.handleError(component, 'Failed to open conditions email', e);
    }
  },
  createConditionsHelper: function (component) {
    try {
      component.set('v.showFlow', true);
      const flow = component.find('createConditionsFlow');
      const inputVariables = [
        {
          name: 'recordId',
          type: 'String',
          value: component.get('v.recordId')
        }
      ];
      flow.startFlow(component.get('v.createConditionsFlowAPIName'), inputVariables);
    } catch (e) {
      this.handleError(component, 'Failed to create conditions', e);
    }
  },
  handleDownloadHelper: function (component) {
    const conditionTables = component.get('v.conditionTables');
    let conditions = component.get('v.initialConditions');

    const outstandingConditions = conditionTables.filter((table) =>
      table.rows.every((condition) => condition.data.Status__c !== this.CONDITION_STATUSES.CLEARED)
    );

    const conditionsToDownload = [];

    outstandingConditions.forEach((table) => {
      table.rows.forEach((condition) => {
        if (condition.isSelected) {
          conditionsToDownload.push(condition);
        }
      });
    });

    let downloadUrl = this.getDownloadUrl(
      conditionsToDownload.length
        ? conditionsToDownload
        : conditions.filter((condition) => condition.data.Status__c === this.CONDITION_STATUSES.APPROVED)
    );
    window.open(downloadUrl, '_blank');
  },
  getDownloadUrl: function (conditions) {
    let downloadUrl = `/sfc/servlet.shepherd/document/download`;

    for (const condition of conditions) {
      if (condition.contentVersions) {
        for (const contentVersion of condition.contentVersions) {
          if (downloadUrl.indexOf(contentVersion.ContentDocumentId) < 0) {
            downloadUrl += '/' + contentVersion.ContentDocumentId;
          }
        }
      }
    }

    downloadUrl += '?';

    return downloadUrl;
  },
  flowStatusChangeHelper: function (component, event) {
    try {
      if (event.getParam('status') === 'FINISHED') {
        component.set('v.showFlow', false);
        $A.enqueueAction(component.get('c.doInit'));
      }
    } catch (e) {
      this.handleError(component, 'Failed to handle flow status change', e);
    }
  },
  cancelFlow: function (component) {
    try {
      component.set('v.showFlow', false);
      $A.enqueueAction(component.get('c.doInit'));
    } catch (e) {
      this.handleError(component, 'Failed to cancel flow', e);
    }
  },
  handleConditionRowEventHelper: function (component, event) {
    try {
      const action = event.getParam('action');
      if (action === 'selectionChange') {
        this.updateSelectAllState(component);
      }
    } catch (e) {
      this.handleError(component, 'Failed to handle condition row event', e);
    }
  },
  updateSelectAllState: function (component) {
    const tables = component.get('v.conditionTables') || [];
    tables.forEach(function (table) {
      if (table.rows && table.rows.length > 0) {
        table.allSelected = table.rows.every(function (row) {
          return row.isSelected;
        });
      } else {
        table.allSelected = false;
      }
    });
    component.set('v.conditionTables', tables);
  },
  handleSelectAllHelper: function (component, event) {
    const isChecked = event.getSource().get('v.checked');
    const tableIndexStr = event.getSource().get('v.name');
    const tableIndex = tableIndexStr !== undefined && tableIndexStr !== null ? Number.parseInt(tableIndexStr, 10) : -1;
    const tables = component.get('v.conditionTables') || [];
    if (tableIndex > -1 && tables[tableIndex]) {
      const table = tables[tableIndex];
      table.allSelected = isChecked;
      if (table && table.rows) {
        table.rows.forEach(function (condition) {
          condition.isSelected = isChecked;
        });
      }
    } else {
      console.warn('handleSelectAllHelper: invalid table index', tableIndexStr);
      component.set('v.warningMessage', 'Could not select all: invalid table index');
      component.set('v.showWarningNotification', true);
    }
    component.set('v.conditionTables', tables);
  },
  sortArrayOfObjects: function (component, array, field) {
    try {
      if (array) {
        array.sort((a, b) => {
          if (a[`${field}`] > b[`${field}`]) {
            return 1;
          }
          if (a[`${field}`] < b[`${field}`]) {
            return -1;
          }

          return 0;
        });
      }
    } catch (e) {
      this.handleError(component, 'Failed to sort array of objects', e);
    }
  },
  handleError: function (c, context, error) {
    globalThis.plog.error('ConditionsViewer', { message: context, error: error });
    const extracted = Array.isArray(error) ? error[0] : error;
    const message = (extracted && extracted.message) || extracted;
    c.set('v.errorMessage', context + ': ' + message);
    c.set('v.showErrorNotification', true);
  }
});