FROM python:slim
LABEL maintainer="plaschke@adobe.com"

ARG VERSION

RUN pip install github3.py

COPY ./assets/modify-repo-without-cloning.py /opt/bin/modify.py

ENTRYPOINT ["/opt/bin/modify.py"]