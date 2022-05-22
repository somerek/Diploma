FROM python:3.10-slim as py-image
FROM py-image as builder
WORKDIR /opt/app
RUN pip install --no-cache-dir --upgrade pip flask flask_restful flask_cors flask_sqlalchemy \
    flask_migrate sqlalchemy requests python-dateutil future python-dotenv flask_wtf
COPY setup.py .
COPY requirements.txt .
COPY app ./app
RUN python setup.py bdist_wheel

FROM py-image
RUN apt-get update && apt-get install --no-install-recommends -y curl stress && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
ENV dir=/opt/app/dist
COPY --from=builder ${dir}/music_page-1.0.0-py3-none-any.whl ${dir}/
RUN pip install --no-cache-dir ${dir}/music_page-1.0.0-py3-none-any.whl
WORKDIR /opt/app
COPY --from=builder /opt/app/app/app.py .
EXPOSE 5000/tcp
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
HEALTHCHECK --interval=5s --timeout=5s --retries=5 CMD curl --fail \
    http://localhost:5000/music_page/api/v1.0/years || exit 1
CMD [ "sh", "-c", "/entrypoint.sh"]
