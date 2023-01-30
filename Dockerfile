FROM python:3.10 AS build 
USER root
COPY /app /app
RUN pip3 install -r /app/requirements.txt -t /python-env
RUN ls /python-env

FROM debian:11 AS deb
RUN apt-get update && apt-get install -y ffmpeg 

FROM gcr.io/distroless/base
USER root
COPY --from=build /python-env /python-env
COPY --from=deb /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app /app

ENV PYTHONPATH=/python-env
WORKDIR /app
CMD ["main.py"]
