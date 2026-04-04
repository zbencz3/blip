import SwiftUI

enum TemplateLibrary {
    static let all: [WebhookTemplate] = [
        // CI/CD
        WebhookTemplate(
            name: "GitHub Actions",
            icon: "circle.hexagongrid.fill",
            iconColor: Color(white: 0.15),
            description: "Notify on workflow completion",
            curlTemplate: """
            # Add to .github/workflows/your-workflow.yml
            - name: Notify on completion
              if: always()
              run: |
                curl -s -X POST {{WEBHOOK_URL}} \\
                  -H 'Content-Type: application/json' \\
                  -d '{
                    "title": "GitHub Actions",
                    "message": "Workflow ${{ github.workflow }} ${{ job.status }}",
                    "thread_id": "github-actions"
                  }'
            """,
            category: .cicd
        ),

        WebhookTemplate(
            name: "GitLab CI",
            icon: "diamond.fill",
            iconColor: Color(red: 0.91, green: 0.36, blue: 0.13),
            description: "Notify on pipeline status",
            curlTemplate: """
            # Add to .gitlab-ci.yml
            notify:
              stage: .post
              script:
                - |
                  curl -s -X POST {{WEBHOOK_URL}} \\
                    -H 'Content-Type: application/json' \\
                    -d "{
                      \\"title\\": \\"GitLab CI\\",
                      \\"message\\": \\"Pipeline $CI_PIPELINE_ID $CI_JOB_STATUS\\",
                      \\"thread_id\\": \\"gitlab-ci\\"
                    }"
              when: always
            """,
            category: .cicd
        ),

        WebhookTemplate(
            name: "Docker",
            icon: "shippingbox.fill",
            iconColor: Color(red: 0.01, green: 0.48, blue: 0.88),
            description: "Container health check alert",
            curlTemplate: """
            # Docker health check with notification
            docker run --health-cmd='curl -sf http://localhost/ || exit 1' \\
              --health-interval=30s \\
              --health-retries=3 \\
              myapp

            # Or in a monitoring script:
            STATUS=$(docker inspect --format='{{.State.Health.Status}}' myapp)
            if [ "$STATUS" != "healthy" ]; then
              curl -s -X POST {{WEBHOOK_URL}} \\
                -H 'Content-Type: application/json' \\
                -d "{
                  \\"title\\": \\"Docker Alert\\",
                  \\"message\\": \\"Container myapp is $STATUS\\",
                  \\"interruption_level\\": \\"time-sensitive\\"
                }"
            fi
            """,
            category: .cicd
        ),

        WebhookTemplate(
            name: "Terraform",
            icon: "cube.fill",
            iconColor: Color(red: 0.38, green: 0.27, blue: 0.82),
            description: "Notify on apply completion",
            curlTemplate: """
            # Add to your Terraform apply script
            terraform apply -auto-approve
            EXIT_CODE=$?

            if [ $EXIT_CODE -eq 0 ]; then
              MSG="Terraform apply succeeded"
            else
              MSG="Terraform apply failed (exit $EXIT_CODE)"
            fi

            curl -s -X POST {{WEBHOOK_URL}} \\
              -H 'Content-Type: application/json' \\
              -d "{
                \\"title\\": \\"Terraform\\",
                \\"message\\": \\"$MSG\\",
                \\"thread_id\\": \\"terraform\\"
              }"
            """,
            category: .cicd
        ),

        // Monitoring
        WebhookTemplate(
            name: "Uptime Kuma",
            icon: "waveform.path.ecg",
            iconColor: Color(red: 0.24, green: 0.78, blue: 0.51),
            description: "Downtime and recovery alerts",
            curlTemplate: """
            # In Uptime Kuma → Notifications → Add New
            # Type: Webhook
            # URL: {{WEBHOOK_URL}}
            # Body (JSON):
            {
              "title": "Uptime Kuma",
              "message": "{{msg}}",
              "interruption_level": "{{#eq heartbeatJSON.status 0}}time-sensitive{{else}}active{{/eq}}"
            }
            """,
            category: .monitoring
        ),

        // Home Automation
        WebhookTemplate(
            name: "Home Assistant",
            icon: "house.fill",
            iconColor: Color(red: 0.03, green: 0.69, blue: 0.75),
            description: "Trigger from automations",
            curlTemplate: """
            # In Home Assistant automation or script:
            rest_command:
              blip_notify:
                url: {{WEBHOOK_URL}}
                method: POST
                headers:
                  Content-Type: application/json
                payload: >
                  {
                    "title": "Home Assistant",
                    "message": "{{ message }}",
                    "thread_id": "home-assistant"
                  }

            # Then in an automation action:
            - service: rest_command.blip_notify
              data:
                message: "Front door opened"
            """,
            category: .homeAutomation
        ),

        // Scripts
        WebhookTemplate(
            name: "Cron Job",
            icon: "clock.fill",
            iconColor: Color(red: 0.95, green: 0.65, blue: 0.0),
            description: "Script completion notification",
            curlTemplate: """
            #!/bin/bash
            # Wrap your cron job with notifications
            # Example crontab entry:
            # 0 2 * * * /path/to/notify-wrapper.sh

            /path/to/your-script.sh
            EXIT_CODE=$?

            curl -s -X POST {{WEBHOOK_URL}} \\
              -H 'Content-Type: application/json' \\
              -d "{
                \\"title\\": \\"Cron Job\\",
                \\"message\\": \\"$(basename $0) finished (exit $EXIT_CODE)\\",
                \\"thread_id\\": \\"cron\\"
              }"
            """,
            category: .scripting
        ),

        WebhookTemplate(
            name: "Shell Script",
            icon: "terminal.fill",
            iconColor: Color(white: 0.3),
            description: "Generic bash notification snippet",
            curlTemplate: """
            #!/bin/bash
            WEBHOOK_URL="{{WEBHOOK_URL}}"

            notify() {
              local title="${1:-Notification}"
              local message="${2:-Done}"
              curl -s -X POST "$WEBHOOK_URL" \\
                -H 'Content-Type: application/json' \\
                -d "{
                  \\"title\\": \\"$title\\",
                  \\"message\\": \\"$message\\"
                }"
            }

            # Usage:
            notify "My Script" "Task completed successfully"
            """,
            category: .scripting
        ),

        WebhookTemplate(
            name: "Python",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: Color(red: 0.22, green: 0.56, blue: 0.87),
            description: "requests library snippet",
            curlTemplate: """
            import requests

            WEBHOOK_URL = "{{WEBHOOK_URL}}"

            def notify(title: str, message: str, thread_id: str = None):
                payload = {"title": title, "message": message}
                if thread_id:
                    payload["thread_id"] = thread_id
                resp = requests.post(WEBHOOK_URL, json=payload)
                resp.raise_for_status()

            # Usage:
            notify("Python Script", "Task finished successfully")
            """,
            category: .scripting
        ),

        WebhookTemplate(
            name: "Node.js",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: Color(red: 0.33, green: 0.65, blue: 0.18),
            description: "fetch/axios snippet",
            curlTemplate: """
            const WEBHOOK_URL = "{{WEBHOOK_URL}}";

            async function notify(title, message, options = {}) {
              const response = await fetch(WEBHOOK_URL, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ title, message, ...options }),
              });
              if (!response.ok) {
                throw new Error(`Notification failed: ${response.statusText}`);
              }
            }

            // Usage:
            await notify("Node.js Script", "Task finished successfully");
            """,
            category: .scripting
        ),
    ]

    static func templates(for category: TemplateCategory) -> [WebhookTemplate] {
        all.filter { $0.category == category }
    }
}
