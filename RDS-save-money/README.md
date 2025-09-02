



Configure IAM permissions
Create an AWS Identity and Access Management (IAM) policy to allow Lambda to start and stop the instance and retrieve information on the instance.

1. Open the IAM console.

2. In the navigation pane, choose Policies.

3. Choose Create Policy.

4. Choose the JSON tab.

5. To grant the required IAM permissions, enter the following policy under the JSON tab:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "rds:StartDBCluster",
                "rds:StopDBCluster",
                "rds:ListTagsForResource",
                "rds:DescribeDBInstances",
                "rds:StopDBInstance",
                "rds:DescribeDBClusters",
                "rds:StartDBInstance"
            ],
            "Resource": "*"
        }
    ]
}
```

6.    Choose Next: Tags.

7.    (Optional) To add a tag, choose Add tag, and then enter the appropriate values for the Key and Value - optional fields.

8.    Choose Next: Review.

9.    On the Review policy page, for Name, enter the name for your policy. Review the Summary section to see the permissions that are granted by your policy.

10.    Choose Create policy.

For more information, see Creating policies using the JSON editor.

### Create an IAM role, and then attach the required policies
1.    Open the IAM console.

2.    In the navigation pane, choose Roles.

3.    Choose Create role.

4.    For Select type of trusted entity, select AWS service.

5.    Under Or select a service to view its use cases, select Lambda.

6.    Choose Next: Permissions.

7.    For Filter-policies, enter the name of the policy that you created in the previous section. After it appears, select the policy. For Filter-policies, enter AWSLambdaBasicExecutionRole. After it appears, select the AWSLambdaBasicExecutionRole managed policy.


8.    Choose Next: Tags.

9.     (Optional) To add a tag, enter the appropriate values for the Key and Value (optional) fields.

10.    Choose Next: Review.

11.    On the Create role page, for Role name, enter the name for the role that you're creating.

12.    Choose Create role.

For more information, see Creating a role for an AWS service (console).

Add tags for DB instances
1.    Open the Amazon RDS console.

2.    In the navigation pane, choose Databases.

3.    Choose the DB instance that you want to start and stop automatically.

4.    In the details section, scroll down to the Tags section.

5.    Under the Tags tab, choose Add. For Tag key, enter autostart. For Value, enter yes. Choose Add to save your changes.

6.    Choose Add again. For Tag key, enter autostop. For Value, enter yes. Choose Add to save your changes.

For more information, see Adding, listing, and removing tags.

### Create a Lambda function to start the tagged DB instances

1.    Open the Lambda console.

2.    In the navigation pane, choose Functions.

3.    Choose Create function.

4.    Choose Author from scratch.

5.    For Function name, enter the name of your function.

6.    For Runtime, select Python 3.7.

7.    For Architecture, keep the default selection of x86_64.

8.    Expand Change default execution role.

9.    For Execution role, select Use an existing role.

10.    For Existing role, select the IAM role that you created.

11.    Choose Create function.

12.    Choose the Code tab.

13.    In the Code source editor, delete the sample code and enter the following code:
```
import boto3
rds = boto3.client('rds')

def lambda_handler(event, context):

    #Start DB Instances
    dbs = rds.describe_db_instances()
    for db in dbs['DBInstances']:
        #Check if DB instance stopped. Start it if eligible.
        if (db['DBInstanceStatus'] == 'stopped'):
            try:
                GetTags=rds.list_tags_for_resource(ResourceName=db['DBInstanceArn'])['TagList']
                for tags in GetTags:
                #if tag "autostart=yes" is set for instance, start it
                    if(tags['Key'] == 'autostart' and tags['Value'] == 'yes'):
                        result = rds.start_db_instance(DBInstanceIdentifier=db['DBInstanceIdentifier'])
                        print ("Starting instance: {0}.".format(db['DBInstanceIdentifier']))
            except Exception as e:
                print ("Cannot start instance {0}.".format(db['DBInstanceIdentifier']))
                print(e)
                

if __name__ == "__main__":
    lambda_handler(None, None)
```
14.    Choose File, choose Save, and then choose Deploy.

15.    Choose the Configuration tab, choose General configuration, and then choose Edit.

16.    Under Timeout, complete the following fields:
For min, select 0.
For sec, select 10.

17.    Choose Save.

Create a Lambda function to stop the tagged DB instances
To create a Lambda function to stop the tagged DB instances, see the previous section Create a Lambda function to start the tagged DB instances. Follow the same steps, but use different code for step 12.

In the Code source editor, delete the sample code and enter the following code:

```
import boto3
rds = boto3.client('rds')

def lambda_handler(event, context):

    #Stop DB instances
    dbs = rds.describe_db_instances()
    for db in dbs['DBInstances']:
        #Check if DB instance is not already stopped
        if (db['DBInstanceStatus'] == 'available'):
            try:
                GetTags=rds.list_tags_for_resource(ResourceName=db['DBInstanceArn'])['TagList']
                for tags in GetTags:
                #if tag "autostop=yes" is set for instance, stop it
                    if(tags['Key'] == 'autostop' and tags['Value'] == 'yes'):
                        result = rds.stop_db_instance(DBInstanceIdentifier=db['DBInstanceIdentifier'])
                        print ("Stopping instance: {0}.".format(db['DBInstanceIdentifier']))
            except Exception as e:
                print ("Cannot stop instance {0}.".format(db['DBInstanceIdentifier']))
                print(e)
                
if __name__ == "__main__":
    lambda_handler(None, None)
```

### Perform function testing
For tagged DB instances that are in the Stopped state, complete the following steps to perform function testing:

1.    Open the Lambda Functions list.

2.    Choose the function that you created to start the DB instances.

3.    Choose Actions, and then choose Test.

4.    Under the Test tab, for Name, enter the name of your event.

5.    Choose Save changes, and then choose Test.

### Create the schedule
You can create rules to set up a schedule. For example, if your weekly maintenance window for the tagged DB instances is Sunday 22:00 - 22:30, then you can create the following rules:

Automatically start the DB instance 30 minutes before the maintenance window begins.
Automatically stop the DB instance 30 minutes after the maintenance window ends.
To create the rule to automatically start the DB instance 30 minutes before the maintenance window, complete the following steps:

1.    Open the Lambda Functions list.

2.    Choose the function that you created to start the DB instances.

3.    Under Function overview, choose Add trigger.

4.    Select EventBridge (CloudWatch Events), and then select Create a new rule.

5.    For Rule name, enter the name of the rule that you want to create.

6.    For Schedule Expression, add a cron expression for the automated schedule (Example: cron(30 21 ? * SUN *)).

7.    Choose Add.

Use the same instructions to create another rule to automatically stop the DB instance 30 minutes after the maintenance window. Be sure to change the name of the rule and the cron expression for the automated schedule accordingly (Example: cron(00 23 ? * SUN *)).
