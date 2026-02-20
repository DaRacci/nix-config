_: {
  services.home-assistant.config = {
    "automation manual" = [
      {
        alias = "Monitoring - Critical Alert Notification";
        id = "monitoring_critical_alert";
        description = "Forward critical Alertmanager alerts to mobile devices";
        mode = "parallel";

        trigger = [
          {
            platform = "webhook";
            webhook_id = "alertmanager_critical";
            allowed_methods = [ "POST" ];
            local_only = true;
          }
        ];

        condition = [
          {
            condition = "template";
            value_template = "{{ trigger.json.status == 'firing' }}";
          }
        ];

        action = [
          {
            service = "notify.mobile_app";
            data = {
              title = "🚨 {{ trigger.json.commonLabels.alertname }}";
              message = "{{ trigger.json.commonAnnotations.summary | default('Alert triggered') }}";
              data = {
                priority = "high";
                channel = "monitoring";
                tag = "monitoring-{{ trigger.json.commonLabels.alertname }}";
              };
            };
          }
        ];
      }
      {
        alias = "Monitoring - Alert Resolved Notification";
        id = "monitoring_alert_resolved";
        description = "Notify when Alertmanager alerts are resolved";
        mode = "parallel";

        trigger = [
          {
            platform = "webhook";
            webhook_id = "alertmanager_critical";
            allowed_methods = [ "POST" ];
            local_only = true;
          }
        ];

        condition = [
          {
            condition = "template";
            value_template = "{{ trigger.json.status == 'resolved' }}";
          }
        ];

        action = [
          {
            service = "notify.mobile_app";
            data = {
              title = "✅ {{ trigger.json.commonLabels.alertname }} Resolved";
              message = "{{ trigger.json.commonAnnotations.summary | default('Alert resolved') }}";
              data = {
                channel = "monitoring";
                tag = "monitoring-{{ trigger.json.commonLabels.alertname }}";
              };
            };
          }
        ];
      }
    ];
  };
}
