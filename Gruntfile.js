module.exports = function(grunt) {
  grunt.initConfig({
    flexpmd: {
      sagescratch: {
        src: 'src/'
      }
    }
  });
  grunt.loadNpmTasks('grunt-flexpmd');
};
