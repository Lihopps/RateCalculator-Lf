remote.add_interface("RateCalculator",
  {
    getGuidata = function(index) return global.gui[index] end
  })