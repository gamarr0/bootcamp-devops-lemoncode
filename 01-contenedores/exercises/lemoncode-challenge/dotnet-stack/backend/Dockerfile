
FROM mcr.microsoft.com/dotnet/sdk:3.1 as build-env
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /publish

FROM mcr.microsoft.com/dotnet/aspnet:3.1 as runtime
WORKDIR /publish
COPY --from=build-env /publish .

EXPOSE 5000

ENTRYPOINT ["dotnet", "backend.dll"]
CMD ["--urls", "http://topics-api:5000"]