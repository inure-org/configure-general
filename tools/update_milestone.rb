#!/usr/bin/env ruby

require 'docopt'
require 'inure'
require 'uri'

lib = File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'api'
require 'data_selector'
require 'issue_entry'
require 'status_report'

docstring = <<DOCOPT
posta um comentário sobre a configuração atual das issues do milestone no plano de isuses atual

uso:
    #{__FILE__} [--dry-run]
    #{__FILE__} -h | --help

opções:
    -h --help           mostra essa tela.
    --dry-run           printa o body do comentário, mas não posta.

DOCOPT

begin
    doc_options = Docopt::docopt(docstring)

    dry_run = doc_options.fetch('--dry-run', false)

    api = Api.new
    data_selector = DataSelector.new

    all_milestones = api.get_milestones

    puts "determinando milestone atual..."

    current_milestones = data_selector.current_milestones(all_milestones: all_milestones)

    # devemos deixar restando com aquele milestone que deve ser nosso único.
    # caso não seja determinado apenas 1 milestone atual, quitar.
    return unless current_milestones.count == 1
    
    current_milestone = current_milestones.first

    conf_issues = api.get_conf_issues(current_milestone: current_milestone)

    configure_general_project_issues = api.get_configure_general_project_issues

    current_planning_issues = data_selector.current_planning_issues(
        configure_general_project_issues: configure_general_project_issues,
        title: current_milestone.title
    )

    # devemos deixar restando com aquele milestone que deve ser nosso único.
    # caso não seja determinado apenas 1 milestone atual, quitar.
    return unless current_planning_issues.count == 1
    current_planning_issue = current_planning_issues.first

    puts "#{current_planning_issue.web_url} determinado como plano de issue atual."

    current_planning_issue_comments = api.get_current_planning_issue_comments(
        current_planning_issue_iid: current_planning_issue.iid
    )

    last_posted_bot_comment = data_selector.last_posted_bot_comment(
        current_planning_issue_comments: current_planning_issue_comments
    )

    status_report = StatusReport.new(
        last_posted_bot_comment: last_posted_bot_comment,
        conf_issues: conf_issues
    )

    status_report.prepare_comment_body!

    puts status_report.comment_body

    if dry_run
        puts "dry run solicitado, então os dados não serão postados."
        puts "dry run completo."
    else
        puts "postando comentário..."

        api.post_comment(
            current_planning_issue_iid: current_planning_issue.iid,
            body: status_report.comment_body
        )

        puts "postagem de comentário concluída"
    end

rescue Docopt::Exit => 0
    puts e.message

    exit 1
end
