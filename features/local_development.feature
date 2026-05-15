Feature: Local Development
  As a developer  
  I want to run the application locally
  So that I can develop and test features

  Background:
    Given I have an Agile Flow project
    And I am in the project root directory
    And "pyproject.toml" exists

  Scenario: Install dependencies successfully
    Given Python 3.12+ is installed
    And uv is installed
    When I run "uv sync --extra dev"
    Then dependencies should be installed successfully
    And the virtual environment should be created
    And development dependencies should be available

  Scenario: Start development server
    Given dependencies are installed
    When I run "uv run uvicorn app.main:app --reload --port 8080"
    Then the server should start successfully
    And I should see "Uvicorn running on http://127.0.0.1:8080"
    And the application should be accessible at "http://localhost:8080"
    And hot reloading should be enabled

  Scenario: Run code quality checks
    Given dependencies are installed
    When I run "uv run ruff check ."
    Then the linter should execute without errors
    And I should see a summary of any lint issues
    
    When I run "uv run ruff format ."
    Then the formatter should execute successfully
    And code should be formatted according to project standards

  Scenario: Run type checking
    Given dependencies are installed  
    When I run "uv run mypy app/"
    Then type checking should execute
    And I should see type checking results
    And mypy should check the app directory

  Scenario: Run tests with coverage
    Given dependencies are installed
    When I run "uv run pytest --cov=app --cov-report=term-missing"
    Then all tests should execute
    And I should see test results
    And I should see coverage report
    And coverage should be calculated for the app directory

  Scenario: Run database migrations
    Given dependencies are installed
    And DATABASE_URL environment variable is set
    When I run "uv run alembic upgrade head"
    Then migrations should be applied successfully
    And the database should be up to date
    And I should see migration status

  Scenario: Create new migration
    Given dependencies are installed
    And DATABASE_URL environment variable is set
    And I have made model changes
    When I run "uv run alembic revision --autogenerate -m 'add user table'"
    Then a new migration file should be created
    And the migration should contain my model changes
    And the migration should be in "alembic/versions/" directory

  Scenario: Build Docker container locally
    Given I have Docker installed
    And I am in the project root
    When I run "docker build -t agile-flow-app ."
    Then the container should build successfully
    And I should see "Successfully tagged agile-flow-app:latest"

  Scenario: Development workflow integration
    Given I have git hooks configured
    When I make changes to Python files
    And I attempt to push changes
    Then the pre-push hook should run
    And it should execute "uv run ruff check ."
    And it should execute "uv run pytest"
    And the push should only succeed if checks pass