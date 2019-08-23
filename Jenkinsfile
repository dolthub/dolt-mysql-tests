pipeline {
    agent none
    stages {
        stage('Test') {
            agent {
                kubernetes {
                    label "liquidata-inc-ld-build"
                }
            }
            environment {
                PATH = "~/go/bin:${env.PATH}"
                DOLTHUBCRED = credentials("system-account-dolthub-creds")
                DOLTHUBCONFIG = credentials("system-account-dolthub-config")
                DOLTTESTLINKER = true
            }
            steps {
                dir ("") {
                    sh 'set +x; mkdir -p ~/.dolt/creds'
                    sh 'set +x; echo -n "$DOLTHUBCONFIG" > ~/.dolt/config_global.json'
                    sh 'set +x; DOLTHUBCREDNAME=$(basename $DOLTHUBCRED); if [ ! -f ~/.dolt/creds/$DOLTHUBCREDNAME ]; then cp -a $DOLTHUBCRED ~/.dolt/creds/$DOLTHUBCREDNAME; fi;'
                }
                dir ("testharness") {
                    sh 'if [ ! -x "$(command -v go)" ]; then ./installgo.sh; fi;'
                    sh './installdolt.sh'
                    script {
                        def status = sh(returnStatus: true, script: './setuprepo.sh')
                        if (status == 3) {
                            currentBuild.result = 'SUCCESS'
                            return
                        }
                        if (status != 0) {
                            currentBuild.result = 'FAILED'
                            return
                        }
                        sh 'echo "`date -u`: Running Tests"'
                        sh './runtest.sh'
                        sh 'echo "`date -u`: Finished Tests"'
                        sh './updaterepo.sh'
                    }
                }
            }
        }
    }
}
