"""BDD test runner for Agile Flow features."""

from pytest_bdd import scenarios

# Import all step definition modules to register the steps
import step_defs.test_framework_bootstrap
import step_defs.test_framework_upgrade
import step_defs.test_local_development
import step_defs.test_deployment_pipeline

# Import all scenarios from feature files
scenarios('../features/')