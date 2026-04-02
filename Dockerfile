FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["src/ElohimShop.API/ElohimShop.API.csproj", "src/ElohimShop.API/"]
COPY ["src/ElohimShop.Application/ElohimShop.Application.csproj", "src/ElohimShop.Application/"]
COPY ["src/ElohimShop.Infrastructure/ElohimShop.Infrastructure.csproj", "src/ElohimShop.Infrastructure/"]
COPY ["src/ElohimShop.Domain/ElohimShop.Domain.csproj", "src/ElohimShop.Domain/"]

RUN dotnet restore "src/ElohimShop.API/ElohimShop.API.csproj"
COPY . .

RUN dotnet publish "src/ElohimShop.API/ElohimShop.API.csproj" -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:5000
EXPOSE 5000
ENTRYPOINT ["dotnet", "ElohimShop.API.dll"]