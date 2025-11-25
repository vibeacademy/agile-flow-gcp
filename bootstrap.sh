#!/bin/bash

# Agile Flow Bootstrap Wizard
# Guides users through progressive refinement of project context

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Status file to track progress
STATUS_FILE=".claude/.bootstrap-status"

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${BLUE}Agile Flow Bootstrap Wizard${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_phase() {
    local phase=$1
    local title=$2
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Phase $phase: $title${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

check_phase_complete() {
    local phase=$1
    if [ -f "$STATUS_FILE" ]; then
        grep -q "^$phase:complete$" "$STATUS_FILE" 2>/dev/null && return 0
    fi
    return 1
}

mark_phase_complete() {
    local phase=$1
    mkdir -p "$(dirname "$STATUS_FILE")"
    echo "$phase:complete" >> "$STATUS_FILE"
}

get_current_phase() {
    if ! check_phase_complete "phase1"; then
        echo "1"
    elif ! check_phase_complete "phase2"; then
        echo "2"
    elif ! check_phase_complete "phase3"; then
        echo "3"
    elif ! check_phase_complete "phase4"; then
        echo "4"
    else
        echo "complete"
    fi
}

show_progress() {
    echo ""
    echo -e "${CYAN}Progress:${NC}"

    if check_phase_complete "phase1"; then
        echo -e "  ${GREEN}[✓] Phase 1: Product Definition${NC}"
    else
        echo -e "  ${YELLOW}[ ] Phase 1: Product Definition${NC}"
    fi

    if check_phase_complete "phase2"; then
        echo -e "  ${GREEN}[✓] Phase 2: Technical Architecture${NC}"
    else
        echo -e "  ${YELLOW}[ ] Phase 2: Technical Architecture${NC}"
    fi

    if check_phase_complete "phase3"; then
        echo -e "  ${GREEN}[✓] Phase 3: Agent Specialization${NC}"
    else
        echo -e "  ${YELLOW}[ ] Phase 3: Agent Specialization${NC}"
    fi

    if check_phase_complete "phase4"; then
        echo -e "  ${GREEN}[✓] Phase 4: Workflow Activation${NC}"
    else
        echo -e "  ${YELLOW}[ ] Phase 4: Workflow Activation${NC}"
    fi
    echo ""
}

phase1_product() {
    print_phase "1" "Product Definition"

    echo ""
    echo "This phase creates your Product Requirements Document (PRD)."
    echo "The Product Manager agent will help you define:"
    echo "  • Product vision and goals"
    echo "  • Target audience"
    echo "  • Core features and priorities"
    echo "  • Success metrics"
    echo "  • Initial roadmap"
    echo ""

    if [ -f "docs/PRODUCT-REQUIREMENTS.md" ]; then
        print_warning "docs/PRODUCT-REQUIREMENTS.md already exists"
        read -p "Overwrite? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            print_info "Keeping existing PRD"
            mark_phase_complete "phase1"
            return 0
        fi
    fi

    echo ""
    print_info "Starting Claude Code with /bootstrap-product command..."
    echo ""
    echo -e "${CYAN}In Claude Code, run:${NC}"
    echo -e "${GREEN}  /bootstrap-product${NC}"
    echo ""
    echo "Follow the prompts to define your product."
    echo ""

    read -p "Press Enter when Phase 1 is complete..."

    if [ -f "docs/PRODUCT-REQUIREMENTS.md" ] && [ -f "docs/PRODUCT-ROADMAP.md" ]; then
        mark_phase_complete "phase1"
        print_success "Phase 1 complete! PRD and Roadmap created."
    else
        print_error "PRD or Roadmap not found. Please complete Phase 1."
        return 1
    fi
}

phase2_architecture() {
    print_phase "2" "Technical Architecture"

    if ! check_phase_complete "phase1"; then
        print_error "Phase 1 (Product Definition) must be completed first"
        return 1
    fi

    echo ""
    echo "This phase defines your technical architecture."
    echo "The System Architect agent will help you define:"
    echo "  • Technology stack"
    echo "  • System design and components"
    echo "  • Data models"
    echo "  • API contracts"
    echo "  • Infrastructure approach"
    echo ""
    echo "The architect will reference your PRD to ensure alignment."
    echo ""

    if [ -f "docs/TECHNICAL-ARCHITECTURE.md" ]; then
        print_warning "docs/TECHNICAL-ARCHITECTURE.md already exists"
        read -p "Overwrite? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            print_info "Keeping existing architecture"
            mark_phase_complete "phase2"
            return 0
        fi
    fi

    echo ""
    print_info "Starting Claude Code with /bootstrap-architecture command..."
    echo ""
    echo -e "${CYAN}In Claude Code, run:${NC}"
    echo -e "${GREEN}  /bootstrap-architecture${NC}"
    echo ""
    echo "Follow the prompts to define your architecture."
    echo ""

    read -p "Press Enter when Phase 2 is complete..."

    if [ -f "docs/TECHNICAL-ARCHITECTURE.md" ]; then
        mark_phase_complete "phase2"
        print_success "Phase 2 complete! Technical architecture defined."
    else
        print_error "Architecture document not found. Please complete Phase 2."
        return 1
    fi
}

phase3_agents() {
    print_phase "3" "Agent Specialization"

    if ! check_phase_complete "phase2"; then
        print_error "Phase 2 (Technical Architecture) must be completed first"
        return 1
    fi

    echo ""
    echo "This phase specializes agents with your project context."
    echo "Based on your PRD and architecture, agents will be updated with:"
    echo "  • Project-specific tech stack"
    echo "  • Coding standards and conventions"
    echo "  • Testing requirements"
    echo "  • Architecture patterns to follow"
    echo ""
    echo "This makes agents give project-specific guidance instead of generic advice."
    echo ""

    print_info "Starting Claude Code with /bootstrap-agents command..."
    echo ""
    echo -e "${CYAN}In Claude Code, run:${NC}"
    echo -e "${GREEN}  /bootstrap-agents${NC}"
    echo ""
    echo "The agents will be updated with your project context."
    echo ""

    read -p "Press Enter when Phase 3 is complete..."

    mark_phase_complete "phase3"
    print_success "Phase 3 complete! Agents specialized for your project."
}

phase4_workflow() {
    print_phase "4" "Workflow Activation"

    if ! check_phase_complete "phase3"; then
        print_error "Phase 3 (Agent Specialization) must be completed first"
        return 1
    fi

    echo ""
    echo "This phase activates the development workflow."
    echo "This includes:"
    echo "  • Verifying GitHub project board setup"
    echo "  • Checking branch protection configuration"
    echo "  • Creating initial backlog from PRD features"
    echo "  • Populating Ready column with first tickets"
    echo ""

    print_info "Starting Claude Code with /bootstrap-workflow command..."
    echo ""
    echo -e "${CYAN}In Claude Code, run:${NC}"
    echo -e "${GREEN}  /bootstrap-workflow${NC}"
    echo ""
    echo "Follow the prompts to activate your workflow."
    echo ""

    read -p "Press Enter when Phase 4 is complete..."

    mark_phase_complete "phase4"
    print_success "Phase 4 complete! Workflow activated."
}

show_completion() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}            ${GREEN}Bootstrap Complete!${NC}                              ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your Agile Flow project is ready for development!"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Start Claude Code: ${GREEN}claude${NC}"
    echo "  2. Check board status: ${GREEN}/sprint-status${NC}"
    echo "  3. Pick up first ticket: ${GREEN}/work-ticket${NC}"
    echo ""
    echo -e "${CYAN}Available commands:${NC}"
    echo "  /groom-backlog     - Manage and prioritize backlog"
    echo "  /work-ticket       - Implement next ticket"
    echo "  /review-pr         - Review pull requests"
    echo "  /check-milestone   - Track milestone progress"
    echo "  /evaluate-feature  - Assess feature requests"
    echo "  /release-decision  - Go/no-go for releases"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo "  • CLAUDE.md - Project configuration"
    echo "  • docs/PRODUCT-REQUIREMENTS.md - Your PRD"
    echo "  • docs/PRODUCT-ROADMAP.md - Your roadmap"
    echo "  • docs/TECHNICAL-ARCHITECTURE.md - Your architecture"
    echo ""
}

run_phase() {
    local phase=$1
    case $phase in
        1) phase1_product ;;
        2) phase2_architecture ;;
        3) phase3_agents ;;
        4) phase4_workflow ;;
        *) print_error "Unknown phase: $phase" ;;
    esac
}

main() {
    print_header

    # Check if running in a git repo
    if [ ! -d ".git" ]; then
        print_warning "Not a git repository. Initialize with 'git init' first."
        read -p "Initialize git now? (Y/n): " init_git
        if [[ ! $init_git =~ ^[Nn]$ ]]; then
            git init
            print_success "Git repository initialized"
        fi
    fi

    # Create docs directory if it doesn't exist
    mkdir -p docs

    show_progress

    current=$(get_current_phase)

    if [ "$current" == "complete" ]; then
        show_completion
        exit 0
    fi

    echo -e "${CYAN}Current phase: $current${NC}"
    echo ""

    # Option to skip to specific phase or continue
    echo "Options:"
    echo "  [Enter] Continue with Phase $current"
    echo "  [1-4]   Jump to specific phase"
    echo "  [r]     Reset and start over"
    echo "  [q]     Quit"
    echo ""
    read -p "Choice: " choice

    case $choice in
        ""|" ")
            run_phase $current
            ;;
        [1-4])
            run_phase $choice
            ;;
        r|R)
            rm -f "$STATUS_FILE"
            print_info "Progress reset. Starting from Phase 1."
            run_phase 1
            ;;
        q|Q)
            print_info "Exiting. Run ./bootstrap.sh to continue later."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Continue to next phases
    while true; do
        current=$(get_current_phase)
        if [ "$current" == "complete" ]; then
            show_completion
            exit 0
        fi

        echo ""
        read -p "Continue to Phase $current? (Y/n): " cont
        if [[ $cont =~ ^[Nn]$ ]]; then
            print_info "Pausing. Run ./bootstrap.sh to continue later."
            exit 0
        fi

        run_phase $current
    done
}

# Run main function
main "$@"
