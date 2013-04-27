#!/bin/sh
echo "Copy to staging.viblio.com ..."
scp -i ../va-services.pem $1 ubuntu@staging.viblio.com:/home/ubuntu
echo "Copy to ec2-54-244-140-186.us-west-2.compute.amazonaws.com ..."
scp -i ../va-services.pem $1 ubuntu@ec2-54-244-140-186.us-west-2.compute.amazonaws.com:/home/ubuntu
