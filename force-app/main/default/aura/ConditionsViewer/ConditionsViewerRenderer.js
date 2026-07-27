// eslint-disable-next-line no-unused-expressions
({
  unrender: function (component, helper) {
    const observer = component.get('v.resizeObserver');
    if (observer) {
      observer.disconnect();
      component.set('v.resizeObserver', null);
    }
    this.superUnrender();
  }
});