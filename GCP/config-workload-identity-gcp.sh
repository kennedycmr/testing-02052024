#!/bin/bash

### Where is our pipeline running?
printf "Select number indicating where pipeline is run:\n"
printf "1. Github\n"
printf "2. Bitbucket\n"
printf "3. Other\n"
read PIPELINE_VENDOR


case $PIPELINE_VENDOR in

  1)
    export PIPELINE_VENDOR="Github"
    printf "Configuring for pipeline vendor $PIPELINE_VENDOR...\n\n"
    printf "exiting as we don't yet support github."
    exit 0
    ;;

  2)
    export PIPELINE_VENDOR="Bitbucket"
    printf "Configuring for pipeline vendor $PIPELINE_VENDOR...\n\n"
    ;;

  3)
    printf "Unable to continue for pipeline vendor 'Other'. Exiting.\n\n"
    exit 0
    ;;

  *)
    printf "Unable to continue for pipeline vendor 'Unknown'. Exiting.\n\n"
    exit 0
    ;;
esac



### Define Variables
export GCP_PROJECT_ID=xxxxxxxxx
export WORKLOAD_POOL_NAME=xxxxxxxxx
export WORKLOAD_POOL_DISPLAY="Automated Pipeline Actions"
export WORKLOAD_POOL_DESCRIPTION=$WORKLOAD_POOL_DISPLAY
export WORKLOAD_ID_POOL_LOCATION="global"



export WORKLOAD_POOL_PROVIDER_NAME=xxxxxxxxxxx
export DEPLOY_SA='xxxxxxxxx'
export DEPLOYENVUUID='{xxxxxxx}'
export REPOUUID='{xxxxxxxx}'
export ISSUER_URL="xxxxxxxxx"
export AUDIENCES="xxxxxxxx"


### Pipeline vendor neutral variables
echo -n "Enter GCP Project ID? (default: $GCP_PROJECT_ID): "
read ans
case $ans in
    ""     )  ;;  # set to default/existing value
    *      )  export GCP_PROJECT_ID=$ans;;  # set to entered value
esac
printf "set GCP_PROJECT_ID = $GCP_PROJECT_ID\n\n"


echo -n "Enter WORKLOAD_POOL_NAME to be created? (default: $WORKLOAD_POOL_NAME): "
read ans
case $ans in
    ""     )  ;;  # set to default/existing value
    *      )  export WORKLOAD_POOL_NAME=$ans;;  # set to entered value
esac
printf "set WORKLOAD_POOL_NAME = $WORKLOAD_POOL_NAME\n\n"


echo -n "Enter WORKLOAD_POOL_DISPLAY to be created? (default: $WORKLOAD_POOL_DISPLAY): "
read ans
case $ans in
    ""     )  ;;  # set to default/existing value
    *      )  export WORKLOAD_POOL_DISPLAY=$ans;;  # set to entered value
esac
printf "set WORKLOAD_POOL_DISPLAY = $WORKLOAD_POOL_DISPLAY\n\n"


echo -n "Enter WORKLOAD_POOL_DESCRIPTION to be created? (default: $WORKLOAD_POOL_DISPLAY): "
read ans
case $ans in
    ""     )  export WORKLOAD_POOL_DESCRIPTION=$WORKLOAD_POOL_DISPLAY;;  # set to default/existing value
    *      )  export WORKLOAD_POOL_DESCRIPTION=$ans;;  # set to entered value
esac
printf "set WORKLOAD_POOL_DESCRIPTION = $WORKLOAD_POOL_DESCRIPTION\n\n"


echo -n "Enter WORKLOAD_ID_POOL_LOCATION to be created? (default: $WORKLOAD_ID_POOL_LOCATION): "
read ans
case $ans in
    ""     )  ;;  # set to default/existing value
    *      )  export WORKLOAD_ID_POOL_LOCATION=$ans;;  # set to entered value
esac
printf "set WORKLOAD_ID_POOL_LOCATION = $WORKLOAD_ID_POOL_LOCATION\n\n"









### Enable APIs
printf "\nEnabling APIs...\n"
APIS="cloudresourcemanager iamcredentials iam sts serviceusage"

for API in ${APIS}; do
    printf "\nenabling ${API}.googleapis.com..."
    gcloud services enable "${API}.googleapis.com"
done

printf "\n waiting 30 seconds for API's to be fully enabled..."
sleep 30



### Create workload identity pool
printf "\nCreating workload identity pool...\n"
gcloud iam workload-identity-pools create ${WORKLOAD_POOL_NAME} \
--project="${GCP_PROJECT_ID}" \
--location="global" \
--display-name="${WORKLOAD_POOL_NAME}" \
--description="GCP Access for Bitbucket Pipeline Resources"



### Create workload provider pool
printf "\ncreating workload provider pool...\n"
gcloud iam workload-identity-pools providers create-oidc "${WORKLOAD_POOL_PROVIDER_NAME}" \
--location="global" \
--workload-identity-pool=${WORKLOAD_POOL_NAME} \
--issuer-uri=${ISSUER_URL} \
--attribute-mapping="google.subject=assertion.sub,attribute.deploymentenvironmentuuid=assertion.deploymentEnvironmentUuid,attribute.repositoryuuid=assertion.repositoryUuid" \
--allowed-audiences=${AUDIENCES} \
--attribute-condition="(attribute.deploymentenvironmentuuid == '${DEPLOYENVUUID}') && (attribute.repositoryuuid == '${REPOUUID}')"



### Grant principle access to Deploy account 
printf "\nGetting project number...\n"
export GCP_PROJECT_NUMBER="$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')"
export PRINCIPAL_SET="principalSet://iam.googleapis.com/projects/${GCP_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WORKLOAD_POOL_NAME}/attribute.deploymentenvironmentuuid/${DEPLOYENVUUID}"



printf "\nGranting iam-policy-binding to ${DEPLOY_SA}...\n"
gcloud iam service-accounts add-iam-policy-binding ${DEPLOY_SA} \
--member="${PRINCIPAL_SET}" \
--role='roles/iam.serviceAccountTokenCreator'

gcloud iam service-accounts add-iam-policy-binding ${DEPLOY_SA} \
--member="${PRINCIPAL_SET}" \
--role='roles/iam.serviceAccountUser'

gcloud iam service-accounts add-iam-policy-binding ${DEPLOY_SA} \
--member="${PRINCIPAL_SET}" \
--role='roles/iam.workloadIdentityUser'


