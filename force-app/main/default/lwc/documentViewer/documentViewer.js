import { api, LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDocs from '@salesforce/apex/DocumentViewerController.getDocs';
import deleteFile from '@salesforce/apex/DocumentViewerController.deleteFile';
import renameFolder from '@salesforce/apex/DocumentViewerController.renameFolder';
import renameFile from '@salesforce/apex/DocumentViewerController.renameFile';
import getLoanConditions from '@salesforce/apex/DocumentViewerController.getLoanConditions';
import relateFileToCondition from '@salesforce/apex/DocumentViewerController.relateFileToCondition';
import changeFolder from '@salesforce/apex/DocumentViewerController.changeFolder';
import getDefaultFolders from '@salesforce/apex/FileUploaderController.getDefaultFolders';


export default class DocumentViewer extends NavigationMixin(LightningElement) {
	@api recordId;
	@track isLoading = true;
	@track allFolders = [];
	@track folders = [];
	@track docs = [];
	@track foldersToFilesMap = new Map();
	@track filter;
	@track deleteModalOpen = false;
	@track fileToDelete;
	@track renameFolderModalOpen = false;
	@track isNewFolderNameInvalid = true;
	@track fileToRename;
	@track isNewFileNameInvalid = true;
	@track renameFileModalOpen = false;
	@track folderToChange;
	@track changeFolderModalOpen = false;
	@track isNewFolderForFileInvalid = true;
	@track relateConditionModalOpen = false;
	@track relateConditionDisabled = true;
	@track fileToRelate;
	@track conditions = [];
	@track defaultFolders = [];
	ERROR_TOAST_VARIANT = 'error';
	SUCCESS_TOAST_VARIANT = 'success';

	fileActions = [
		{ label: 'Download', name: 'download' },
		{ label: 'Rename File', name: 'renameFile' },
		{ label: 'Change Folder', name: 'changeFolder' },
		{ label: 'Delete', name: 'delete' },
		{ label: 'Relate to Loan Condition', name: 'relateCondition'}
	];

	fileTableColumns = [
		{label: 'Preview', type:'button-icon', fixedWidth: 65, 
			typeAttributes: {
				iconName: 'utility:preview',
				name: 'preview',
				variant:'bare',
				alternativeText: 'preview',
				disabled: false,
				onclick: '{handlePreview}'
			}
		},
		{label: 'File Type', hideDefaultActions: true, fixedWidth: 75,
			cellAttributes: {
				iconName: { fieldName: 'fileTypeIcon' },
				iconPosition: 'right'
			},
		},
		{label: 'Name', fieldName:'fileNameWithType', hideDefaultActions: true}, 
		{label: 'Condition Name', fieldName:'conditionName', hideDefaultActions: true}, 
		{label: 'Created By', fieldName:'createdBy', hideDefaultActions: true}, 
		{label: 'Created Date', fieldName:'createdDate', type:'date', hideDefaultActions: true,
			typeAttributes: {  
				day: 'numeric',  
				month: 'short',  
				year: 'numeric',  
				hour: '2-digit',  
				minute: '2-digit',  
				second: '2-digit',
				hour12: false
			}
		},
		{label: 'Action', type:'action', fixedWidth: 65, typeAttributes: {
			rowActions: this.fileActions,
			menuAlignment: 'auto'
		}},
		
	];

	@track activeFolders = [];

	connectedCallback() {
		this.showSpinner();
		getDocs({recordId: this.recordId})
			.then((result) => {
				this.onGetDocsSuccess(result);
				this.closeSpinner();
			})
			.catch((e) => {
				console.log(e);
				console.error('e.name => ', e?.name);
				console.error('e.message => ', e?.message);
				console.error('e.stack => ', e?.stack);
				this.onGetDocsFail();
				this.closeSpinner();
			});
	}

	showSpinner() {
		this.isLoading = true;
	}

	closeSpinner() {
		this.isLoading = false;
	}

	onGetDocsSuccess(docs) {
		this.docs = this.getParsedDocs(docs);

		getDefaultFolders()
			.then((result ) => {
				this.onGetDefaultFoldersSuccess(result)
			})
			.catch((e) => {
				console.log(e);
				console.error('e.name => ', e?.name);
				console.error('e.message => ', e?.message);
				console.error('e.stack => ', e?.stack);
				this.closeSpinner();
			});
	}

	onGetDocsFail() {
		this.showToast('An error occurred while retrieving documents', this.ERROR_TOAST_VARIANT);
	}

	showToast(title, variant) {
		const toastEvent = new ShowToastEvent({
			title, 
			variant: variant
		});
		this.dispatchEvent(toastEvent);
	}

	/** Safe message for Apex / wire errors (body may be missing). */
	apexErrorMessage(error, fallback) {
		if (!error) {
			return fallback;
		}
		const body = error.body;
		if (body?.message) {
			return body.message;
		}
		const firstPageError = body?.pageErrors?.[0];
		if (firstPageError?.message) {
			return firstPageError.message;
		}
		if (typeof error.message === 'string' && error.message.length > 0) {
			return error.message;
		}
		return fallback;
	}

	getParsedDocs(docs) {
		const parsedDocs = [];
	
		for (const doc of docs) {
			doc.url = `/sfc/servlet.shepherd/document/download/${doc.id}`;
			doc.fileNameWithType = doc.fileName + '.' + doc.fileType;
			parsedDocs.push(doc);
		}

		return parsedDocs;
	}

	setFolders(parsedDocs) {
		const folders = [];
		const foldersToFilesMap = new Map();

		// Replace this with your list of default folders
		const defaultFolders = this.defaultFolders;

		// Iterate through default folders and add them to the folders array
		for (const folder of defaultFolders) {
			folders.push({
				name: folder.value,
				data: [], // Empty array since no documents are found
				newName: folder.value
			});
			this.activeFolders.push(folder.value);
			foldersToFilesMap.set(folder.value, []);
		}

		for (const doc of parsedDocs) {
			const folderName = doc.folderName || 'No Folder';
			doc.folderName = folderName;

			if (!foldersToFilesMap.has(folderName)) {
				folders.push({
					name: folderName,
					data: [doc],
					newName: folderName
				});
				this.activeFolders.push(folderName);
				foldersToFilesMap.set(folderName, [doc]);
				continue;
			}

			const foundFolder = folders.find(element => element.name === folderName);
			foundFolder.data.push(doc);
			const docsByFolder = [...foldersToFilesMap.get(folderName), doc];
			foldersToFilesMap.set(folderName, docsByFolder);
		}

		this.folders = folders;

		this.folders.sort((a, b) => {
			if (a.name === 'No Folder') return -1;
			if (b.name === 'No Folder') return 1;
			return a.name.localeCompare(b.name);
		});

		this.foldersToFilesMap = foldersToFilesMap;
			}

	onGetDefaultFoldersSuccess(folders) {
		const defaultFolders = [];
	
		for (const folder of folders) {
			defaultFolders.push({
				label: folder.MasterLabel,
				value: folder.MasterLabel
			});
		}

		this.defaultFolders = defaultFolders;

		this.setFolders(this.docs);
		this.allFolders = [...this.folders];
		getLoanConditions({recordId: this.recordId})
			.then((conditions) => {
				const conditionOptions = [{label:'None', value: 'None'}];
				for (const condition of conditions) {
					const option = {label: condition.Name, value: condition.Id}
					conditionOptions.push(option);
				}
				this.conditionOptions = conditionOptions;
			})
			.catch((error) => {
				console.log('error on getLoanConditions');
				console.log(error?.message);
				console.log(error?.stack);
			})
	}

	handleFilterChange(event) {
		this.filter = event.target.value;
	}

	handleFilterFiles() {
		this.showSpinner();
		
		if (this.filter) {
			this.filterFiles();
		} else {
			this.resetFilter();
		}
		
		this.closeSpinner();
	}

	resetFilter() {
		this.folders = this.allFolders;
		this.activeFolders = [];
	}

	filterFiles() {
		this.folders = [];
		this.activeFolders = [];
		const folders = [...this.allFolders];
		const filter = this.filter.toLowerCase();

		for (const folder of folders) {
			const filteredFiles = [];
		
			for (const file of folder.data) {
				if (file.fileNameWithType.toLowerCase().includes(filter)) {
					filteredFiles.push(file);
				}
			}

			if (filteredFiles.length > 0) {
				const newFolder = {...folder, data: filteredFiles};
				this.folders.push(newFolder);
				this.activeFolders.push(folder.name);
			}
		}
	}

	downloadAllFiles() {
		const downloadUrl = this.getDownloadUrl(this.docs);

		this[NavigationMixin.Navigate]({ 
			type:'standard__webPage',
			attributes: { 
				url: downloadUrl
			}
		});
	}

	openRenameFolderModal(event) {
		const folderIndex = event.target.dataset.index;
		this.folderToRename = this.folders[folderIndex];
		this.renameFolderModalOpen = true;
	}

	get renameFolderLabel() {
		return 'Please enter new name for "' + this.folderToRename.name +'" folder';
	}

	closeRenameFolderModal() {
		this.folderToRename = null;
		this.renameFolderModalOpen = false;
		this.isNewFolderNameInvalid = false;
	}

	validateNewFolderName(event) {
		if (event.target.value === undefined || event.target.value == null ) {
			this.isNewFolderNameInvalid = false;
			return;
		}

		const newFolderName = event.target.value.trim();
		this.isNewFolderNameInvalid = !event.target.reportValidity() 
			|| newFolderName === this.folderToRename.name;
		this.folderToRename.newName = event.target.value;
	}

	handleFolderRename() {
		this.showSpinner();
		const oldFolderName = this.folderToRename.name;
		const newFolderName = this.folderToRename.newName;

		const params = {
			recordId : this.recordId,
			oldFolderName : oldFolderName,
			newFolderName : newFolderName.trim()
		};

		this.closeRenameFolderModal();
		renameFolder(params)
			.then(() => {
				const successMessage = 'Folder "' + oldFolderName
					+ '" was successfully renamed to "' + newFolderName.trim() + '".'
				this.showToast(successMessage, this.SUCCESS_TOAST_VARIANT);
				this.connectedCallback();
			})
			.catch(e => {
				this.closeSpinner();
				const errorMessage = this.apexErrorMessage(
					e,
					'An error occurred during folder rename. Please, try again.'
				);
				this.showToast(errorMessage, this.ERROR_TOAST_VARIANT);
			});
	}

	downloadFolder(event) {
		const folderIndex = event.target.dataset.index;
		const folderToDownload = this.folders[folderIndex];
		const downloadUrl = this.getDownloadUrl(folderToDownload.data);

		this[NavigationMixin.Navigate]({ 
			type:'standard__webPage',
			attributes: { 
				url: downloadUrl
			}
		});
	}

	getDownloadUrl(files) {
		let downloadUrl = `/sfc/servlet.shepherd/document/download`;
	
		for (const file of files) {
			downloadUrl += '/' + file.id;
		}

		downloadUrl += '?';

		return downloadUrl;
	}

	handleRowAction(event) {
		const action = event.detail.action;
		const row = event.detail.row;

		switch (action.name) {
			case 'preview':
				this.handlePreview(row);
				break;
			case 'download':
				this.handleDownload(row);
				break;
			case 'renameFile':
				this.openRenameFileModal(row);
				break;
			case 'changeFolder':
				this.openChangeFolderModal(row);
				break;
			case 'delete':
				this.openDeleteModal(row);
				break;
			case 'relateCondition':
				this.openConditionPickModal(row);
				break;
		}
	}

	handlePreview(row) {
		this[NavigationMixin.Navigate]({ 
			type:'standard__namedPage',
			attributes:{ 
				pageName:'filePreview'
			},
			state:{ 
				selectedRecordId: row.id
			}
		})
	}

	handleDownload(row) {
		this[NavigationMixin.Navigate]({
			type: "standard__webPage",
			attributes: {
				url: row.url,
			},
		});
	}

	openRenameFileModal(row) {
		this.fileToRename = row;
		this.renameFileModalOpen = true;
	}

	closeRenameFileModal() {
		this.fileToRename = null;
		this.isNewFileNameInvalid = true;
		this.renameFileModalOpen = false;
	}

	validateNewFileName(event) {
		const value = event.target.value.trim();
		this.isNewFileNameInvalid = !event.target.reportValidity() 
			|| value === this.fileToRename.fileName || !value;

		if (this.isNewFileNameInvalid) {
			return;
		}
	
		const fileToRename = {...this.fileToRename};
		fileToRename.newName = value;
		this.fileToRename = fileToRename;
	}

	handleFileRename() {
		const fileToRename = {...this.fileToRename};
		this.fileToRename = null;
		this.closeRenameFileModal();
		this.showSpinner();
		const params = {
			fileId: fileToRename.id,
			newFileName: fileToRename.newName
		};

		renameFile(params)
			.then(() => {
				const successMessage = 'File "' + fileToRename.fileName + '.' + fileToRename.fileType
					+ '" was renamed to "' + fileToRename.newName + '.' + fileToRename.fileType + '"';
				this.showToast(successMessage, this.SUCCESS_TOAST_VARIANT);
				this.connectedCallback()
			})
			.catch(error => {
				const errorMessage = this.apexErrorMessage(
					error,
					'An error occurred during file rename. Please, try again.'
				);
				this.showToast(errorMessage, this.ERROR_TOAST_VARIANT);
			})
	}

	openChangeFolderModal(row) {
		this.fileToChangeFolder = row;
		this.changeFolderModalOpen = true;
	}

	closeChangeFolderModal() {
		this.fileToChangeFolder = null;
		this.newFolderForFile = null;
		this.changeFolderModalOpen = false;
		this.isNewFolderForFileInvalid = true;
	}

	get changeFolderOptions() {
		let options = [];
		const uniqueFolderNames = [];
	
		for (const folder of this.folders) {
			if (folder.name !== this.fileToChangeFolder.folderName) {
				options.push({
					label: folder.name,
					value: folder.name
				});
				uniqueFolderNames.push(folder.name);
			}
		}

		const uniqueDefaultFolders = this.defaultFolders.filter(
			(folder) => !uniqueFolderNames.includes(folder.value)
		);

		options = [...options, ...uniqueDefaultFolders];

		return options;
	}

	handleNewFolderSelect(event) {
		this.newFolderForFile = event.target.value;
		this.isNewFolderForFileInvalid = !event.target.value;
	}

	handleFolderChange(event) {
		const params = {
			recordId: this.recordId,
			fileId: this.fileToChangeFolder.id,
			newFolderName: this.newFolderForFile
		};
		this.closeChangeFolderModal();
		this.showSpinner();
	
		changeFolder(params)
			.then(() => {
				this.showToast('Folder was successfully changed', this.SUCCESS_TOAST_VARIANT);
				this.connectedCallback();
			})
			.catch(error => {
				this.closeSpinner();
				console.log('ERROR DURING CHANGE FOLDER');
				console.log(error);
				const errorMessage = this.apexErrorMessage(
					error,
					'An error occurred while changing folder. Please, try again.'
				);
				this.showToast(errorMessage, this.ERROR_TOAST_VARIANT);
			})
	}

	openDeleteModal(row) {
		this.fileToDelete = row;
		this.deleteModalOpen = true;
	}

	closeDeleteModal() {
		this.deleteModalOpen = false;
		this.fileToDelete = null;
	}

	handleFileDelete() {
		const fileToDelete = {...this.fileToDelete};
		this.showSpinner();
		this.closeDeleteModal();

		deleteFile({fileId: fileToDelete.id})
			.then(() => {
				const successMessage = 'File "'
					+ fileToDelete.fileName + '.' + fileToDelete.fileType
					+ '" was successfully deleted.'
				this.showToast(successMessage, this.SUCCESS_TOAST_VARIANT);
				this.connectedCallback();
			})
			.catch(e => {
				const errorMessage = this.apexErrorMessage(
					e,
					'An error occurred during document deletion. Please, try again'
				);
				this.showToast(errorMessage, this.ERROR_TOAST_VARIANT);
				this.closeSpinner();
			})
	}

	openConditionPickModal(row) {
		try {
			this.fileToRelate = row;
			this.relateConditionModalOpen = true;
		} catch(e) {
			console.log('error on openConditionPickModal');
			console.log(e?.message);
			console.log(e?.stack);
		}
	}

	closeConditionPickModal() {
		this.fileToRelate = null;
		this.relateConditionModalOpen = false;
		this.relateConditionDisabled = true;
	}

	handleNewConditionPick(event) {
		this.conditionToRelate = event.target.value !== 'None' ? event.target.value : null;
		this.relateConditionDisabled = event.target.value === this.fileToRelate.conditionId;
	}

	handleConditionRelate() {
		try {
			this.showSpinner();
			relateFileToCondition({fileId: this.fileToRelate.id, conditionId: this.conditionToRelate})
				.then(() => {
					const successMessage = 'File "'
						+ this.fileToRelate.fileName + '.' + this.fileToRelate.fileType
						+ '" was successfully related to condition.';
					this.closeConditionPickModal();
					this.showToast(successMessage, this.SUCCESS_TOAST_VARIANT);
					this.connectedCallback();
				})
				.catch((e) => {
					const errorMessage = this.apexErrorMessage(
						e,
						'An error occurred during Loan Condition change on file. Please, try again'
					);
					this.closeConditionPickModal();
					this.showToast(errorMessage, this.ERROR_TOAST_VARIANT);
					this.closeSpinner();
				})
		} catch(e) {
			console.log('error on handleConditionRelate');
			console.log(e?.message);
			console.log(e?.stack);
		}
	}
 }